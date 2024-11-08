defmodule Docker.Api.Networks do
  @moduledoc false

  alias Docker.Api.Client

  @default_http_timeout_ms Application.compile_env(:excontainers, :default_http_timeout_ms, 60_000)

  def create(config) do
    payload = network_create_payload(config)

    case Client.post("/networks/create", payload, opts: [adapter: [recv_timeout: @default_http_timeout_ms]]) do
      {:ok, %{status: 201, body: body}} -> {:ok, body["Id"]}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, message} -> {:error, message}
    end
  end

  def connect(network_id, container_id, config) do
    payload = network_connect_payload(container_id, config)

    case Client.post("/networks/#{network_id}/connect", payload,
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, message} -> {:error, message}
    end
  end

  def disconnect(network_id, container_id, force \\ true) do
    data = %{Container: container_id, Force: force}

    case Client.post(
           "/networks/#{network_id}/disconnect",
           data,
           opts: [adapter: [recv_timeout: @default_http_timeout_ms]]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, message} -> {:error, message}
    end
  end

  def inspect(network_id) do
    case Client.get("/networks/#{network_id}") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, message} -> {:error, message}
    end
  end

  def remove(network_id) do
    case Client.delete("/networks/#{network_id}") do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, message} -> {:error, message}
    end
  end

  defp network_create_payload(config) do
    %{Name: config.name}
  end

  defp network_connect_payload(container_id, _config) do
    %{Container: container_id}
  end
end
