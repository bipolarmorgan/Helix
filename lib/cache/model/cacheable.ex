alias Helix.Cache.Model.NetworkCache
alias Helix.Cache.Model.ServerCache
alias Helix.Cache.Model.StorageCache
alias Helix.Cache.Model.WebCache

defprotocol Helix.Cache.Model.Cacheable do

  def format_output(data)

end

defimpl Helix.Cache.Model.Cacheable, for: ServerCache do

  alias Helix.Network.Model.Network
  alias Helix.Server.Model.Server
  alias Helix.Software.Model.Storage
  alias Helix.Cache.Model.Cacheable.Utils

  def format_output(row) do
    storages = if row.storages do
      Enum.map(row.storages, fn(storage) ->
        Utils.cast(Storage.ID, storage)
      end)
    else
      nil
    end

    networks = if row.networks do
      Enum.map(row.networks, fn(net) ->
        {network_id, ip} =
          if Map.has_key?(net, "network_id") do
            {net["network_id"], net["ip"]}
          else
            {net.network_id, net.ip}
          end
        %{network_id: Utils.cast(Network.ID, network_id), ip: ip}
      end)
    else
      nil
    end

    %{
      server_id: Utils.cast(Server.ID, row.server_id),
      networks: networks,
      storages: storages
    }
  end
end

defimpl Helix.Cache.Model.Cacheable, for: StorageCache do

  alias Helix.Server.Model.Server
  alias Helix.Software.Model.Storage
  alias Helix.Cache.Model.Cacheable.Utils

  def format_output(row) do
    %{
      storage_id: Utils.cast(Storage.ID, row.storage_id),
      server_id: Utils.cast(Server.ID, row.server_id)
    }
  end
end

defimpl Helix.Cache.Model.Cacheable, for: NetworkCache do

  alias Helix.Network.Model.Network
  alias Helix.Server.Model.Server
  alias Helix.Cache.Model.Cacheable.Utils

  def format_output(row) do
    %{
      network_id: Utils.cast(Network.ID, row.network_id),
      ip: row.ip,
      server_id: Utils.cast(Server.ID, row.server_id)
    }
  end
end

defimpl Helix.Cache.Model.Cacheable, for: WebCache do

  alias HELL.MapUtils
  alias Helix.Network.Model.Network
  alias Helix.Cache.Model.Cacheable.Utils

  def format_output(row) do
    %{
      network_id: Utils.cast(Network.ID, row.network_id),
      ip: row.ip,
      content: MapUtils.atomize_keys(row.content)
    }
  end
end

defmodule Helix.Cache.Model.Cacheable.Utils do
  def cast(id, value) do
    case apply(id, :cast, [value]) do
      {:ok, id} ->
        id
      :error ->
        nil
    end
  end
end
