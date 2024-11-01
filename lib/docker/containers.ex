defmodule Docker.Containers do
  @moduledoc false
  alias Docker.WaitStrategy

  require Logger

  def create(container_config, name \\ nil) do
    Docker.Api.create_container(container_config, name)
  end

  def run(container_config, name \\ nil) do
    with {:error, {:http_error, 404}} <- Docker.Api.create_container(container_config, name),
         Logger.info("Container #{name} is not found"),
         :ok <- Docker.Api.pull_image(container_config.image) do
      Logger.info("Successfully pulled the image #{container_config.image}")
      run(container_config, name)
    else
      {:ok, container_id} ->
        Logger.info("Starting container #{name}, #{container_id}")
        start_and_wait(container_id, container_config)

      {:error, reason} ->
        Logger.info("Failed to run the container #{name}, reason #{inspect(reason)}")
        {:error, reason}
    end
  end

  def start(container_id) do
    Docker.Api.start_container(container_id)
  end

  def stop(container_id, options \\ []) do
    Docker.Api.stop_container(container_id, options)
  end

  def remove(container_id, options \\ []) do
    Docker.Api.remove_container(container_id, options)
  end

  def kill(container_id, signal \\ "SIGKILL") do
    Docker.Api.kill_container(container_id, signal)
  end

  def wait_stop(container_id, condition \\ "not-running") do
    Docker.Api.wait_stop_container(container_id, condition)
  end

  def delete_stopped() do
    Docker.Api.delete_stopped()
  end

  def pause(container_id), do: Docker.Api.pause_container(container_id)

  def unpause(container_id), do: Docker.Api.unpause_container(container_id)

  def info(container_id), do: Docker.Api.inspect_container(container_id)

  def rename(container_id, new_name), do: Docker.Api.rename_container(container_id, new_name)

  def mapped_port(container, container_port), do: mapped_port(container, container_port, 5)

  def mapped_port(_container, _container_port, 0), do: {:error, :missing_port}

  def mapped_port(container, container_port, retries) do
    container_port =
      container_port
      |> set_protocol_to_tcp_if_not_specified

    with {:ok, info} <- info(container) do
      port =
        info.mapped_ports
        |> Map.get(container_port)

      case port do
        nil ->
          # Port mappings are not configured immediately after the container is creating. If the
          # mapping is missing, sleeping and retrying is usually sufficient.
          :timer.sleep(10)
          mapped_port(container, container_port, retries - 1)

        port ->
          {:ok, String.to_integer(port)}
      end
    end
  end

  defp set_protocol_to_tcp_if_not_specified(port) when is_binary(port), do: port
  defp set_protocol_to_tcp_if_not_specified(port) when is_integer(port), do: "#{port}/tcp"

  defp start_and_wait(container_id, container_config) do
    :ok = Docker.Containers.start(container_id)

    if container_config.wait_strategy do
      :ok = WaitStrategy.wait_until_container_is_ready(container_config.wait_strategy, container_id)
    end

    {:ok, container_id}
  end
end
