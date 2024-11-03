defmodule Docker.Api do
  @moduledoc false
  alias __MODULE__

  # API Containers
  defdelegate inspect_container(container_id), to: Api.Containers, as: :inspect

  defdelegate create_container(container_config, name \\ nil), to: Api.Containers, as: :create

  defdelegate start_container(container_id), to: Api.Containers, as: :start

  defdelegate stop_container(container_id, options \\ []), to: Api.Containers, as: :stop

  defdelegate remove_container(container_id, options \\ []), to: Api.Containers, as: :remove

  defdelegate delete_stopped(), to: Api.Containers, as: :delete_stopped

  defdelegate kill_container(container_id, signal \\ "SIGKILL"), to: Api.Containers, as: :kill

  defdelegate wait_stop_container(container_id, condition \\ "not-running"), to: Api.Containers, as: :wait_stop

  # API Networks
  defdelegate create_network(config), to: Api.Networks, as: :create

  defdelegate connect_network(network_id, container_id, config), to: Api.Networks, as: :connect

  defdelegate remove_network(network_id), to: Api.Networks, as: :remove

  # API Images
  defdelegate pull_image(from_image), to: Api.Images, as: :pull

  # API Exec
  defdelegate start_exec(exec_id), to: Api.Exec, as: :start

  defdelegate create_exec(container_id, command), to: Api.Exec, as: :create

  defdelegate inspect_exec(exec_id), to: Api.Exec, as: :inspect
end
