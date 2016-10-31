defmodule HELM.Server.Controller.ServerService do
  use GenServer

  alias HELM.Server.Controller.Server, as: CtrlServers
  alias HELF.Broker

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: :server)
  end

  @doc false
  def init(_args) do
    Broker.subscribe("event:entity:created", cast: &handle_broker_cast/4)
    Broker.subscribe("server:create", call: &handle_broker_call/4)
    Broker.subscribe("server:attach", call: &handle_broker_call/4)
    Broker.subscribe("server:detach", call: &handle_broker_call/4)

    {:ok, nil}
  end

  @doc false
  def handle_broker_cast(pid, "event:entity:created", id, _request),
    do: GenServer.cast(pid, {:server, :from_entity, id})

  @doc false
  def handle_cast({:server, :from_entity, id}, state) do
    CtrlServers.create(%{entity_id: id})
    {:noreply, state}
  end

  @doc false
  def handle_broker_call(pid, "server:create", struct, _request) do
    response = GenServer.call(pid, {:server, :create, struct})
    {:reply, response}
  end
  def handle_broker_call(pid, "server:attach", {server, mobo}, _request) do
    response = GenServer.call(pid, {:server, :attach, server, mobo})
    {:reply, response}
  end
  def handle_broker_call(pid, "server:detach", server, _request) do
    response = GenServer.call(pid, {:server, :detach, server})
    {:reply, response}
  end

  @doc false
  def handle_call({:server, :create, params}, _from, state) do
    with {:ok, server} <- CtrlServers.create(params) do
      Broker.cast("event:server:created", server.server_id)
      {:reply, {:ok, server.server_id}, state}
    else
      error -> {:reply, error, state}
    end
  end
  def handle_call({:server, :attach, server, mobo}, _from, state) do
    case CtrlServers.attach(server, mobo) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} -> {:reply, :error, state}
    end
  end
  def handle_call({:server, :detach, server}, _from, state) do
    case CtrlServers.detach(server) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, _} -> {:reply, :error, state}
    end
  end
end