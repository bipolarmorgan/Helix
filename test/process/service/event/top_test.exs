defmodule Helix.Process.Service.Event.TOPTest do

  use Helix.Test.IntegrationCase

  alias HELL.TestHelper.Random
  alias Helix.Network.Model.Connection.ConnectionClosedEvent
  alias Helix.Process.Model.Process
  alias Helix.Process.Repo
  alias Helix.Process.Service.Event.TOP, as: TOPEvent

  alias Helix.Process.Factory

  # FIXME
  defp reason_we_need_integration_factories do
    alias Helix.Hardware.Factory, as: HardwareFactory
    alias Helix.Hardware.Service.API.Motherboard, as: MotherboardAPI
    alias Helix.Server.Service.API.Server, as: ServerAPI
    alias Helix.Server.Factory, as: ServerFactory

    server = ServerFactory.insert(:server)

    motherboard = HardwareFactory.insert(:motherboard)

    motherboard.slots
    |> Enum.group_by(&(&1.link_component_type))
    |> Enum.map(fn {_, [v| _]} -> v end)
    |> Enum.each(fn slot ->
      component = Helix.Hardware.Fixture.insert(slot.link_component_type)

      MotherboardAPI.link(slot, component)
    end)

    {:ok, server} = ServerAPI.attach(server, motherboard.motherboard_id)

    server
  end

  test "process is killed when it's connection is closed" do
    connection = Random.pk()

    server = reason_we_need_integration_factories()

    process = Factory.insert(
      :process,
      connection_id: connection,
      gateway_id: server.server_id)

    # TODO: factories for events ?
    event = %ConnectionClosedEvent{
      connection_id: connection,
      network_id: Random.pk(),
      tunnel_id: Random.pk(),
      reason: :shutdown
    }

    assert Repo.get(Process, process.process_id)

    TOPEvent.connection_closed(event)

    # Give enough time for all the asynchronous stuff to happen
    :timer.sleep(100)

    refute Repo.get(Process, process.process_id)
  end
end
