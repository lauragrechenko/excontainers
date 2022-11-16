defmodule Docker.Api.Images do
  @moduledoc false

  alias Docker.Api.Client

  @one_minute 60_000

  def pull(from_image) do
    case Tesla.post(Client.plain_text(), "/images/create", "",
           query: %{fromImage: from_image},
           opts: [adapter: [recv_timeout: @one_minute]]
         ) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def inspect(name) do
    case Client.get("/images/#{name}/json") do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end
end
