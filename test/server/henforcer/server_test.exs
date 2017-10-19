defmodule Helix.Server.Henforcer.ServerTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Henforcer.Macros

  alias Helix.Server.Henforcer.Server, as: ServerHenforcer
  alias Helix.Server.Model.Server

  alias Helix.Test.Server.Setup, as: ServerSetup

  describe "server_exists?/1" do
    test "accepts when server exists" do
      {server, _} = ServerSetup.server()

      assert {true, relay} = ServerHenforcer.server_exists?(server.server_id)

      assert_relay relay, [:server]
    end

    test "rejects when server doesn't exists" do
      server_id = Server.ID.generate()
      assert {false, reason, _} = ServerHenforcer.server_exists?(server_id)
      assert reason == {:server, :not_found}
    end
  end

  describe "server_assembled?" do
    test "accepts when server motherboard is assembled" do
      {server, _} = ServerSetup.server()

      assert {true, relay} = ServerHenforcer.server_assembled?(server.server_id)
      assert_relay relay, [:server]
    end

    test "rejects when server has no motherboard attached to it" do
      {server, _} = ServerSetup.server

      server = %{server| motherboard_id: nil}

      assert {false, reason, _} = ServerHenforcer.server_assembled?(server)
      assert reason == {:server, :not_assembled}
    end
  end
end
