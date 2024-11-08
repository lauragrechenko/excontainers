defmodule Docker.Api.Containers do
  @moduledoc false

  alias Docker.Api.Client
  alias Docker.ContainerState

  @default_http_timeout_ms Application.compile_env(:excontainers, :default_http_timeout_ms, 60_000)
  @default_stop_container_timeout_s Application.compile_env(:excontainers, :default_stop_container_timeout_s, 60)

  def create(container_config, name \\ nil) do
    data = container_create_payload(container_config)

    query = %{name: name} |> remove_nil_values

    case Client.post("/containers/create", data, query: query) do
      {:ok, %{status: 201, body: body}} -> {:ok, body["Id"]}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def start(container_id) do
    case Client.post("/containers/#{container_id}/start", %{}) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def restart(container_id, params) do
    query =
      params
      |> Map.take([:t])
      |> remove_nil_values

    case Client.post("/containers/#{container_id}/restart", %{}, query: query) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def stop(container_id, options \\ []) do
    timeout_seconds = Keyword.get(options, :timeout_seconds, @default_stop_container_timeout_s)
    # enough to wait for container timeout
    http_timeout = (timeout_seconds + 1) * 1000

    query = %{t: timeout_seconds} |> remove_nil_values

    case Client.post(
           "/containers/#{container_id}/stop",
           %{},
           query: query,
           opts: [adapter: [recv_timeout: http_timeout]]
         ) do
      {:ok, %{status: status}} when status in [204, 304] -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def remove(container_id, options) do
    query =
      options
      |> Keyword.take([:v, :force, :link])
      |> Enum.into(%{})
      |> remove_nil_values

    case Client.delete("/containers/#{container_id}",
           query: query,
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def kill(container_id, signal \\ "SIGKILL") do
    query = %{signal: signal}

    case Client.post(
           "/containers/#{container_id}/kill",
           %{},
           query: query,
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def delete_stopped() do
    case Client.post("/containers/prune", %{}) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def inspect(container_id) do
    case Client.get("/containers/#{container_id}/json",
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, ContainerState.parse_docker_response(body)}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def wait_stop(container_id, condition \\ "not-running") do
    query = %{condition: condition}

    case Client.post(
           "/containers/#{container_id}/wait",
           %{},
           query: query,
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def pause(container_id) do
    case Client.post("/containers/#{container_id}/pause", %{},
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def unpause(container_id) do
    case Client.post(
           "/containers/#{container_id}/unpause",
           %{},
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def rename(container_id, new_name) do
    case Client.post("/containers/#{container_id}/rename", %{}, query: %{name: new_name}) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  defp container_create_payload(container_config) do
    port_bindings_config =
      container_config.exposed_ports
      |> Enum.map(fn
        {container_port, host_port} -> {container_port, [%{"HostPort" => to_string(host_port)}]}
        port -> {port, [%{"HostPort" => ""}]}
      end)
      |> Enum.into(%{})

    exposed_ports_config =
      container_config.exposed_ports
      |> Enum.map(fn
        {container_port, _host_port} -> {container_port, %{}}
        port -> {port, %{}}
      end)
      |> Enum.into(%{})

    env_config =
      container_config.environment
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)

    volume_bindings =
      container_config.bind_mounts
      |> Enum.map(fn volume_binding ->
        "#{volume_binding.host_src}:#{volume_binding.container_dest}:#{volume_binding.options}"
      end)

    %{
      Image: container_config.image,
      Cmd: container_config.cmd,
      ExposedPorts: exposed_ports_config,
      Env: env_config,
      Labels: container_config.labels,
      HostConfig: %{
        RestartPolicy: container_config.restart_policy,
        PortBindings: port_bindings_config,
        Privileged: container_config.privileged,
        Binds: volume_bindings
      }
    }
    |> remove_nil_values
  end

  defp remove_nil_values(map) do
    map
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end
end
