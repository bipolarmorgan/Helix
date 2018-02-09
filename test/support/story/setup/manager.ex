defmodule Helix.Test.Story.Setup.Manager do

  alias Ecto.Changeset
  alias Helix.Story.Model.Story
  alias Helix.Story.Repo, as: StoryRepo

  alias Helix.Test.Entity.Setup, as: EntitySetup
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Server.Setup, as: ServerSetup

  @doc """
  See docs on `fake_manager/1`
  """
  def manager(opts \\ []) do
    {manager, related} = fake_manager(opts)
    inserted = StoryRepo.insert!(manager)
    {inserted, related}
  end

  @doc """
  - entity_id: Set entity whose Manager belongs to. Defaults to fake entity
  - server_id: Set server ID. Defaults to fake server
  - network_id: Set network ID. Defaults to fake network.
  """
  def fake_manager(opts \\ []) do
    entity_id = Keyword.get(opts, :entity_id, EntitySetup.id())
    server_id = Keyword.get(opts, :server_id, ServerSetup.id())
    network_id = Keyword.get(opts, :network_id, NetworkHelper.id())

    manager =
      %Story.Manager{
        entity_id: entity_id,
        server_id: server_id,
        network_id: network_id
      }

    changeset = Changeset.change(manager)

    related =
      %{
        changeset: changeset
      }

    {manager, related}
  end
end
