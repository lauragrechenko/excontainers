defmodule Docker.Containers do
  @moduledoc false
  alias Docker.WaitStrategy

  def create(container_config, name \\ nil) do
    Docker.Api.create_container(container_config, name)
  end

  def run(container_config, name \\ nil) do
    with {:error, {:http_error, 404}} <- Docker.Api.create_container(container_config, name),
         :ok <- Docker.Api.pull_image(container_config.image) do
      run(container_config, name)
    else
      {:ok, container_id} ->
        start_and_wait(container_id, container_config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start(container_id) do
    Docker.Api.start_container(container_id)
  end

  def stop(container_id, options \\ []) do
    Docker.Api.stop_container(container_id, options)
  end

  def remove(container_id, options \\ %{}) do
    Docker.Api.remove_container(container_id, options)
  end

  def kill(container_id, signal \\ "SIGKILL") do
    Docker.Api.kill_container(container_id, signal)
  end

  def wait_stop(container_id, condition \\ "not-running") do
    Docker.Api.wait_stop_container(container_id, condition)
  end

  def pause(container_id), do: Docker.Api.pause_container(container_id)

  def unpause(container_id), do: Docker.Api.unpause_container(container_id)

  def info(container_id), do: Docker.Api.inspect_container(container_id)

  def rename(container_id, new_name), do: Docker.Api.rename_container(container_id, new_name)

  def mapped_port(container, container_port) do
    container_port =
      container_port
      |> set_protocol_to_tcp_if_not_specified

    case info(container) do
      {:ok, info} ->
        port =
          info.mapped_ports
          |> Map.get(container_port)
          |> String.to_integer()

        {:ok, port}

      {:error, message} ->
        {:error, message}
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
