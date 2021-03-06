defmodule Helix.Entity.Internal.EntityTest do

  use Helix.Test.Case.Integration

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Entity.Internal.Entity, as: EntityInternal
  alias Helix.Entity.Model.Entity

  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Component.Helper, as: ComponentHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Entity.Helper, as: EntityHelper
  alias Helix.Test.Entity.Setup, as: EntitySetup

  describe "entity creation" do
    test "succeeds with valid params" do
      params =
        %{
          entity_id: EntityHelper.id(),
          entity_type: :account
        }

      {:ok, entity} = EntityInternal.create(params)

      assert entity.entity_id == params.entity_id
    end

    test "fails when entity_type is invalid" do
      params = %{entity_type: :foobar, entity_id: "::"}
      {:error, cs} = EntityInternal.create(params)
      assert :entity_type in Keyword.keys(cs.errors)
    end
  end

  describe "fetch/1" do
    test "returns entity on success" do
      {entity, _} = EntitySetup.entity()

      result = EntityInternal.fetch(entity.entity_id)

      assert result
      assert result.entity_id == entity.entity_id
    end

    test "returns nil if entity doesn't exists" do
      refute EntityInternal.fetch(EntityHelper.id())
    end
  end

  describe "fetch_by_server/1" do
    test "returns entity if server is owned" do
      {server, %{entity: entity}} = ServerSetup.server()

      result = EntityInternal.fetch_by_server(server.server_id)

      assert result
      assert result.entity_id == entity.entity_id
    end

    test "returns nil if server is not owned" do
      refute EntityInternal.fetch_by_server(ServerHelper.id())
    end
  end

  describe "delete/1" do
    test "removes entry" do
      {entity, _} = EntitySetup.entity()

      assert EntityInternal.fetch(entity.entity_id)

      EntityInternal.delete(entity)

      refute EntityInternal.fetch(entity.entity_id)

      CacheHelper.sync_test()
    end
  end

  describe "link_component/2" do
    test "succeeds with entity struct" do
      {entity, _} = EntitySetup.entity()
      component_id = ComponentHelper.id()

      {:ok, link} = EntityInternal.link_component(entity, component_id)

      assert link.component_id == component_id
      assert link.entity_id == entity.entity_id

      CacheHelper.sync_test()
    end

    test "fails when entity doesn't exist" do
      component_id = ComponentHelper.id()
      {:error, _} = EntityInternal.link_component(%Entity{}, component_id)
    end
  end

  describe "unlink_component/2" do
    test "removing entity ownership over components is idempotent" do
      # Create a server assigned to `entity`. So we know for sure that that
      # entity owns at least the initial components
      {_, %{entity: entity}} = ServerSetup.server()

      components = EntityInternal.get_components(entity)

      # 5 initial components for Freeplay server + 5 for Campaign server
      assert length(components) == 10

      component = Enum.random(components)

      EntityInternal.unlink_component(component.component_id)
      EntityInternal.unlink_component(component.component_id)

      new_components = EntityInternal.get_components(entity)

      refute components == new_components
      assert length(components) == length(new_components) + 1

      CacheHelper.sync_test()
    end
  end

  describe "link_server/2" do
    test "succeeds with entity struct" do
      {entity, _} = EntitySetup.entity()

      server_id = ServerHelper.id()

      {:ok, link} = EntityInternal.link_server(entity, server_id)

      assert link.server_id == server_id
      assert link.entity_id == entity.entity_id

      CacheHelper.sync_test()
    end

    test "fails when entity doesn't exist" do
      server_id = ServerHelper.id()
      {:error, _} = EntityInternal.link_server(%Entity{}, server_id)
    end
  end

  describe "unlink_server/2" do
    test "removing entity ownership over servers is idempotent" do
      {server, %{entity: entity}} = ServerSetup.server()

      # Two initial servers (1 Freeplay + 1 Campaign)
      assert 2 == length(EntityInternal.get_servers(entity))

      EntityInternal.unlink_server(server.server_id)
      EntityInternal.unlink_server(server.server_id)

      # 1 remaining server
      assert 1 == length(EntityInternal.get_servers(entity))

      CacheHelper.sync_test()
    end
  end
end
