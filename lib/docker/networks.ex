defmodule Docker.Networks do
  @moduledoc false

  def create(config) do
    Docker.Api.create_network(config)
  end

  def connect(network_id, container_id, config) do
    Docker.Api.connect_network(network_id, container_id, config)
  end

  def remove(network_id) do
    Docker.Api.remove_network(network_id)
  end
end
