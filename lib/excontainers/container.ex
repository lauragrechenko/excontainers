defmodule Excontainers.Container do
  @moduledoc """
  GenServer to interact with a docker container.
  """
  use GenServer

  @enforce_keys [:config]
  defstruct [:config, container_id: nil]

  @default_call_timeout 60_000

  @syn_scope :syn_scope

  @doc """
  Starts a container and blocks until container is ready.
  """
  def start_link(config, name \\ "") do
    GenServer.start_link(__MODULE__, [config, name])
  end

  @doc """
  Stops the Container GenServer.
  When terminated in a non-brutal way, it also stops the container on Docker.
  """
  def stop(container_id, ignore \\ true, reason \\ :normal, timeout \\ @default_call_timeout) do
    case :syn.whereis_name({@syn_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, {:stop, ignore, reason}, timeout)
    end
  end

  @doc """
  Stops the Container GenServer.
  It also kills the container on Docker.
  """
  def kill(container_id, signal \\ "SIGKILL", timeout \\ @default_call_timeout) do
    case :syn.whereis_name({@syn_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, {:kill, signal}, timeout)
    end
  end

  def delete(container_id, timeout \\ @default_call_timeout) do
    case :syn.whereis_name({@syn_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, :delete, timeout)
    end
  end

  @doc """
  Returns the configuration used to build the container.
  """
  def config(container_id) do
    case :syn.whereis_name({@syn_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, :config)
    end
  end

  @doc """
  Returns the ID of the container on Docker.
  """
  def container_id(pid), do: GenServer.call(pid, :container_id)

  @doc """
  Returns the port on the _host machine_ that is mapped to the given port inside the _container_.
  """
  def mapped_port(container_id, port) do
    case :syn.whereis_name({@syn_scope, container_id}) do
      :undefined ->
        {:error, :no_container}

      pid ->
        GenServer.call(pid, {:mapped_port, port})
    end
  end

  # Server
  @impl true
  def init([config, name]) do
    send(self(), {:init, name})
    {:ok, %__MODULE__{config: config, container_id: nil}}
  end

  @impl true
  def handle_info({:init, name}, state) do
    case Docker.Containers.run(state.config, name) do
      {:ok, container_id} ->
        :syn.register(@syn_scope, container_id, self())
        {:noreply, %__MODULE__{state | container_id: container_id}}

      {:error, _message} = error ->
        {:stop, error, state}
    end
  end

  @impl true
  def handle_call(:config, _from, state) do
    {:reply, state.config, state}
  end

  def handle_call(:container_id, _from, state) do
    {:reply, state.container_id, state}
  end

  def handle_call({:mapped_port, port}, _from, state) do
    {:ok, mapped_port} = Docker.Containers.mapped_port(state.container_id, port)
    {:reply, mapped_port, state}
  end

  def handle_call(:inspect, _from, state) do
    result = Docker.Containers.info(state.container_id)
    {:reply, result, state}
  end

  def handle_call(:pause, _from, state) do
    result = Docker.Containers.pause(state.container_id)
    {:reply, result, state}
  end

  def handle_call(:unpause, _from, state) do
    result = Docker.Containers.unpause(state.container_id)
    {:reply, result, state}
  end

  def handle_call(:delete, _from, state) do
    Docker.Containers.stop(state.container_id)
    Docker.Containers.remove(state.container_id)
    {:stop, :normal, :ok, state}
  end

  def handle_call({:stop, true, reason}, _from, state) do
    Docker.Containers.stop(state.container_id)
    {:stop, reason, :ok, state}
  end

  def handle_call({:stop, false, reason}, _from, state) do
    case Docker.Containers.stop(state.container_id) do
      :ok ->
        {:stop, reason, :ok, %__MODULE__{state | container_id: nil}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:kill, signal}, _from, state) do
    case Docker.Containers.kill(state.container_id, signal) do
      :ok ->
        {:stop, signal, :ok, %__MODULE__{state | container_id: nil}}

      error ->
        {:reply, error, state}
    end
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
