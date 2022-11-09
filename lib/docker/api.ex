defmodule Docker.Api do
  @moduledoc false
  alias __MODULE__

  # API Operation
  defdelegate ping(), to: Api.Operation, as: :ping

  # API Containers
  defdelegate inspect_container(container_id), to: Api.Containers, as: :inspect

  defdelegate create_container(container_config, name \\ nil), to: Api.Containers, as: :create

  defdelegate start_container(container_id), to: Api.Containers, as: :start

  defdelegate stop_container(container_id, options \\ []), to: Api.Containers, as: :stop

  defdelegate remove_container(container_id, options \\ %{}), to: Api.Containers, as: :remove

  defdelegate kill_container(container_id, signal \\ "SIGKILL"), to: Api.Containers, as: :kill

  defdelegate wait_stop_container(container_id, condition \\ "not-running"), to: Api.Containers, as: :wait_stop

  defdelegate pause_container(container_id), to: Api.Containers, as: :pause

  defdelegate unpause_container(container_id), to: Api.Containers, as: :unpause

  # API Networks
  defdelegate create_network(config), to: Api.Networks, as: :create

  defdelegate connect_network(network_id, container_id, config), to: Api.Networks, as: :connect

  defdelegate disconnect_network(network_id, container_id, force \\ true), to: Api.Networks, as: :disconnect

  defdelegate inspect_network(network_id), to: Api.Networks, as: :inspect

  defdelegate remove_network(network_id), to: Api.Networks, as: :remove

  # API Images
  defdelegate pull_image(from_image), to: Api.Images, as: :pull

  defdelegate inspect_image(name), to: Api.Images, as: :inspect

  # API Exec
  defdelegate start_exec(exec_id), to: Api.Exec, as: :start

  defdelegate create_exec(container_id, command), to: Api.Exec, as: :create

  defdelegate inspect_exec(exec_id), to: Api.Exec, as: :inspect
end
