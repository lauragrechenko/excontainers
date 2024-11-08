defmodule Docker.Api.Client do
  @moduledoc false

  use Tesla

  alias Docker.Api.{DockerHost, HackneyHost}

  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)
  adapter(Tesla.Adapter.Hackney)

  def plain_text do
    Tesla.client(
      [{Tesla.Middleware.BaseUrl, base_url()}],
      Tesla.Adapter.Hackney
    )
  end

  defp base_url do
    api_version = Application.get_env(:excontainers, :docker_api_version)
    docker_host() <> "/" <> api_version
  end

  defp docker_host do
    HackneyHost.from_docker_host(DockerHost.detect())
  end
end
