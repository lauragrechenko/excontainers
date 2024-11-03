defmodule Excontainers.Container do
  @moduledoc """
  GenServer to interact with a docker container.
  """
  use GenServer

  @enforce_keys [:config]
  defstruct [:config, container_id: nil]

  @type stop_params :: %{
          stop_timeout: integer(),
          remove?: boolean(),
          remove_volume?: boolean()
        }

  @type kill_params :: %{
          signal: String.t(),
          remove?: boolean(),
          remove_volume?: boolean()
        }

  @default_call_timeout 60_000
  @default_kill_signal "SIGKILL"
  @stop_container_timeout 30_000
  @syn_excontainers_scope :syn_excontainers_scope

  @doc """
  Starts a container and blocks until container is ready.
  """
  @spec start_link(config :: Docker.Container.t(), name :: String.t() | nil) :: {:ok, pid}
  def start_link(config, name \\ nil) do
    GenServer.start_link(__MODULE__, [config, name])
  end

  @doc """
  Stops the Container GenServer.
  When terminated in a non-brutal way, it also stops the container on Docker.
  """
  @spec stop(container_id :: String.t(), params :: stop_params(), timeout: integer()) :: :ok | {:error, term()}
  def stop(container_id, params, timeout \\ @default_call_timeout) do
    case :syn.whereis_name({@syn_excontainers_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, {:stop, params}, timeout)
    end
  end

  @doc """
  Returns the ID of the container on Docker.
  """
  def container_id(pid), do: GenServer.call(pid, :container_id)

  @doc """
  Returns the port on the _host machine_ that is mapped to the given port inside the _container_.
  """
  def mapped_port(pid, port) when is_pid(pid), do: GenServer.call(pid, {:mapped_port, port})

  def mapped_port(container_id, port) do
    case :syn.whereis_name({@syn_excontainers_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, {:mapped_port, port})
    end
  end

  @impl true
  def init([config, name]) do
    Process.flag(:trap_exit, true)
    send(self(), {:init, name})
    {:ok, %__MODULE__{config: config, container_id: nil}}
  end

  @impl true
  def init(config, name \\ nil), do: init([config, name])

  @impl true
  def handle_info({:init, name}, state) do
    case Docker.Containers.run(state.config, name) do
      {:ok, container_id} ->
        :syn.register(@syn_excontainers_scope, container_id, self())
        {:noreply, %__MODULE__{state | container_id: container_id}}

      {:error, _message} = error ->
        {:stop, error, state}
    end
  end

  def handle_call(:container_id, _from, state) do
    {:reply, state.container_id, state}
  end

  def handle_call({:mapped_port, port}, _from, state) do
    {:ok, mapped_port} = Docker.Containers.mapped_port(state.container_id, port)
    {:reply, mapped_port, state}
  end

  def handle_call({:stop, params}, _from, state) do
    remove? = Map.get(params, :remove?, false)
    stop_timeout = Map.get(params, :stop_timeout, @stop_container_timeout)

    result = Docker.Containers.stop(state.container_id, timeout_seconds: stop_timeout)
    Docker.Containers.wait_stop(state.container_id)

    case remove? do
      true ->
        remove_volume? = Map.get(params, :remove_volume?, false)
        force? = Map.get(params, :force?, true)
        Docker.Containers.remove(state.container_id, v: remove_volume?, force: force?)

      false ->
        :ok
    end

    {:stop, :normal, result, state}
  end

  @impl true
  def terminate(reason, %{container_id: container_id} = _state) when container_id != nil do
    Docker.Containers.stop(container_id)
    reason
  end

  def terminate(reason, _state) do
    reason
  end
end
