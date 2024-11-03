defmodule Docker.Container do
  @moduledoc """
  Specification for a _container_.
  """
  alias Docker.Container

  @enforce_keys [:image]

  defstruct [
    :image,
    cmd: nil,
    environment: %{},
    exposed_ports: [],
    wait_strategy: nil,
    privileged: false,
    bind_mounts: [],
    labels: %{},
    restart_policy: %{}
  ]

  @type t :: %__MODULE__{
          image: String.t(),
          cmd: String.t(),
          environment: map(),
          exposed_ports: list(),
          wait_strategy: Docker.CommandWaitStrategy.t(),
          privileged: boolean(),
          bind_mounts: list(),
          labels: map(),
          restart_policy: map()
        }

  @doc """
  Creates a _container_ from the given image.

  ## Options

  - `bind_mounts` sets the files or the directories on the _host machine_ to mount into the _container_.
  - `cmd` sets the command to run in the container
  - `environment` sets the environment variables for the container
  - `exposed_ports` sets the ports to expose to the host
  - `privileged` indicates whether the container should run in privileged mode (default false)
  - `wait_strategy` sets the strategy to adopt to determine whether the container is ready for use
  - `restart_policy` sets the behavior of container restarts when they exit or encounter failures
  """
  def new(image, opts \\ []) do
    exposed_ports =
      Keyword.get(opts, :exposed_ports, [])
      |> Enum.map(&set_protocol_to_tcp_if_not_specified/1)

    %Container{
      image: image,
      bind_mounts: opts[:bind_mounts] || [],
      cmd: opts[:cmd],
      environment: opts[:environment] || %{},
      exposed_ports: exposed_ports,
      privileged: opts[:privileged] || false,
      wait_strategy: opts[:wait_strategy],
      restart_policy: opts[:restart_policy] || %{}
    }
  end

  defp set_protocol_to_tcp_if_not_specified(port) when is_binary(port), do: port
  defp set_protocol_to_tcp_if_not_specified(port) when is_integer(port), do: "#{port}/tcp"
end
