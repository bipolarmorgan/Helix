defmodule Helix.Network.Action.Tunnel do

  alias Helix.Server.Model.Server
  alias Helix.Network.Internal.Tunnel, as: TunnelInternal
  alias Helix.Network.Model.Connection
  alias Helix.Network.Model.Network
  alias Helix.Network.Model.Tunnel
  alias Helix.Network.Query.Tunnel, as: TunnelQuery

  alias Helix.Network.Event.Connection.Closed, as: ConnectionClosedEvent
  alias Helix.Network.Event.Connection.Started, as: ConnectionStartedEvent

  @type create_tunnel_errors ::
    {:error, {:gateway_id, :notfound}}
    | {:error, {:target_id, :notfound}}
    | {:error, {:links, :notfound}}
    | {:error, {:gateway_id, :disconnected}}
    | {:error, {:target_id, :disconnected}}
    | {:error, {:links_id, :disconnected}}

  @spec create_tunnel(Network.t, Server.id, Server.id, Tunnel.bounce) ::
    {:ok, Tunnel.t}
    | {:error, Tunnel.creation_error}
  def create_tunnel(network, gateway_id, target_id, bounce),
    do: TunnelInternal.create(network, gateway_id, target_id, bounce)

  @spec delete(Tunnel.idt) ::
    :ok
  defdelegate delete(tunnel),
    to: TunnelInternal

  @spec start_connection(Tunnel.t, Connection.type, Connection.meta) ::
    {:ok, Connection.t, [ConnectionStartedEvent.t]}
    | {:error, Ecto.Changeset.t}
  def start_connection(tunnel, type, meta \\ nil) do
    case TunnelInternal.start_connection(tunnel, type, meta) do
      {:ok, connection} ->
        {:ok, connection, [ConnectionStartedEvent.new(connection)]}

      {:error, _} ->
        {:error, :internal}
    end
  end

  @spec close_connection(Connection.t, Connection.close_reasons) ::
    [ConnectionClosedEvent.t]
  def close_connection(connection, reason \\ :normal) do
    with :ok <- TunnelInternal.close_connection(connection) do
      [ConnectionClosedEvent.new(connection, reason)]
    end
  end

  @spec close_connections_where(Server.idt, Server.idt, Connection.type, term) ::
    [ConnectionClosedEvent.t]
  @doc """
  Closes all connections where:
  - gateway is `from`
  - target is `to`
  - type is `type`
  - Optional: filter meta values according to `meta_filter`

  The `meta_filter` param must be a function that receives the connection's meta
  field and returns true if that connection should be closed, false otherwise.
  Note that the connection's meta may be empty (nil). Also note that IDs stored
  on the meta will return as string, so use `to_string/1`.
  """
  def close_connections_where(from, to, type, meta_filter \\ false) do
    # Applies the meta_filter to the resulting set of connections. If no filter
    # is given, then the user wants to delete all returned connections.
    apply_filter = fn connections ->
      if meta_filter do
        connections
        |> Enum.filter(fn(entry) -> meta_filter.(entry.meta) end)
      else
        connections
      end
    end

    from
    |> TunnelQuery.connections_on_tunnels_between(to)
    |> Enum.filter(&(&1.connection_type == type))
    |> apply_filter.()
    |> Enum.map(&close_connection/1)
    |> Enum.concat()
  end
end
