defmodule Excontainers.Network do
  @moduledoc """
  GenServer to interact with a docker network.
  """
  use GenServer

  @enforce_keys [:config]
  defstruct [:config, network_id: nil]

  @default_call_timeout 60_000

  @syn_excontainers_scope :syn_excontainers_scope

  @doc """
  Starts a network.
  """
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc """
  Stops the network GenServer.
  When terminated in a non-brutal way, it also stops the network on Docker.
  """
  def remove(network_id, ignore \\ true, timeout \\ @default_call_timeout) do
    case :syn.lookup(@syn_excontainers_scope, network_id) do
      :undefined ->
        {:error, :no_network}

      {pid, _} ->
        GenServer.call(pid, {:remove, ignore}, timeout)
    end
  end

  def connect(network_id, container_id, config \\ [], timeout \\ @default_call_timeout) do
    case :syn.lookup(@syn_excontainers_scope, network_id) do
      :undefined ->
        {:error, :no_network}

      {pid, _} ->
        GenServer.call(pid, {:connect, container_id, config}, timeout)
    end
  end

  def disconnect(network_id, container_id, force \\ true, timeout \\ @default_call_timeout) do
    case :syn.lookup(@syn_excontainers_scope, network_id) do
      :undefined ->
        {:error, :no_network}

      {pid, _} ->
        GenServer.call(pid, {:disconnect, container_id, force}, timeout)
    end
  end

  @doc """
  Returns the configuration used to build the container.
  """
  def config(network_id) do
    case :syn.lookup(@syn_excontainers_scope, network_id) do
      :undefined ->
        {:error, :no_network}

      {pid, _} ->
        GenServer.call(pid, :config)
    end
  end

  @doc """
  Returns the ID of the container on Docker.
  """
  def network_id(pid), do: GenServer.call(pid, :network_id)

  # Server
  @impl true
  def init(config) do
    send(self(), :init)
    {:ok, %__MODULE__{config: config, network_id: nil}}
  end

  @impl true
  def handle_info(:init, state) do
    case Docker.Networks.create(state.config) do
      {:ok, network_id} ->
        :syn.register(@syn_excontainers_scope, network_id, self())
        {:noreply, %__MODULE__{state | network_id: network_id}}

      {:error, _message} = error ->
        {:stop, error, state}
    end
  end

  @impl true
  def handle_call(:config, _from, state) do
    {:reply, state.config, state}
  end

  def handle_call(:network_id, _from, state) do
    {:reply, state.network_id, state}
  end

  def handle_call({:connect, container_id, config}, _from, state) do
    result = Docker.Networks.connect(state.network_id, container_id, config)
    {:reply, result, state}
  end

  def handle_call({:disconnect, container_id, force}, _from, state) do
    result = Docker.Networks.disconnect(state.network_id, container_id, force)
    {:reply, result, state}
  end

  def handle_call(:inspect, _from, state) do
    result = Docker.Networks.inspect(state.network_id)
    {:reply, result, state}
  end

  def handle_call({:remove, true}, _from, state) do
    Docker.Networks.remove(state.network_id)
    {:stop, :normal, :ok, state}
  end

  def handle_call({:remove, false}, _from, state) do
    case Docker.Networks.remove(state.network_id) do
      :ok ->
        {:stop, :normal, :ok, %__MODULE__{state | network_id: nil}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def terminate(reason, %{network_id: network_id} = _state) when network_id != nil do
    Docker.Networks.remove(network_id)
    reason
  end

  def terminate(reason, _state) do
    reason
  end
end
