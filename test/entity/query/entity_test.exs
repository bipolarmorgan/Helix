defmodule Helix.Entity.Query.EntityTest do

  use Helix.Test.Case.Integration

  alias Helix.Entity.Action.Entity, as: EntityAction
  alias Helix.Entity.Query.Entity, as: EntityQuery

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Entity.Setup, as: EntitySetup

  describe "get_servers/1" do
    test "returns list of server ids owned by entity" do
      {entity, _} = EntitySetup.entity()

      server_ids = Enum.map(1..5, fn _ ->
        server_id = ServerHelper.id()

        EntityAction.link_server(entity, server_id)

        server_id
      end)

      server_ids = MapSet.new(server_ids)
      entity_servers = MapSet.new(EntityQuery.get_servers(entity))
      assert MapSet.equal?(server_ids, entity_servers)

      CacheHelper.sync_test()
    end
  end
end
