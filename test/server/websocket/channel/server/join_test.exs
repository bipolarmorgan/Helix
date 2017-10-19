defmodule Helix.Server.Websocket.Channel.Server.JoinTest do

  use Helix.Test.Case.Integration

  import Phoenix.ChannelTest

  alias Helix.Server.Query.Server, as: ServerQuery

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Channel.Helper, as: ChannelHelper
  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Server.State.Helper, as: ServerStateHelper

  @moduletag :driver

  @internet_id NetworkHelper.internet_id()

  describe "ServerJoin" do
    test "can connect to owned server with simple join message" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()

      entity_id = socket.assigns.entity_id

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, gateway_ip)

      # Joins the channel
      assert {:ok, bootstrap, new_socket} = join(socket, topic, %{})

      # `gateway` data is valid
      assert new_socket.assigns.gateway.server_id == gateway.server_id
      assert new_socket.assigns.gateway.entity_id == entity_id
      assert new_socket.assigns.gateway.ip == gateway_ip

      # metadata is valid
      assert new_socket.assigns.meta.access_type == :local
      assert new_socket.assigns.meta.network_id == network_id
      assert new_socket.assigns.meta.counter == 0

      # `destination` data is identical to `gateway` data
      assert new_socket.assigns.destination == new_socket.assigns.gateway

      # Some other stuff
      assert new_socket.joined
      assert new_socket.topic == topic

      # It returned the server bootstrap
      assert bootstrap.data.filesystem
      assert bootstrap.data.logs
      assert bootstrap.data.processes
      assert bootstrap.data.password
      assert bootstrap.data.name

      CacheHelper.sync_test()
    end

    test "invalid format" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()

      network_id = @internet_id
      str_network_id = to_string(network_id)
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)

      bad_topic1 = "server:" <> gateway_ip <> "#0"
      bad_topic2 = "server:" <> str_network_id <> "#0"
      bad_topic3 = "server:" <> str_network_id <> "@" <> gateway_ip <> "bad#0"

      assert {:error, reason1} = join(socket, bad_topic1, %{})
      assert {:error, reason2} = join(socket, bad_topic2, %{})
      assert {:error, reason3} = join(socket, bad_topic3, %{})

      assert reason1 == reason2 and reason2 == reason3
      assert reason1 == %{data: "bad_request"}
    end

    test "can not connect locally to a server the player does not own" do
      {socket, _} = ChannelSetup.create_socket()
      {random_server, _} = ServerSetup.server()

      network_id = @internet_id
      random_server_ip = ServerQuery.get_ip(random_server.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, random_server_ip)

      assert {:error, reason} = join(socket, topic, %{})
      assert reason.data == "server_bad_owner"
    end

    test "can not connect to a remote server with an incorrect password" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, destination_ip)

      params = %{
        "gateway_ip" => gateway_ip,
        "password" => "wrongpass"
      }

      assert {:error, reason} = join(socket, topic, params)
      assert reason.data == "server_bad_password"
    end

    test "can not connect to a remote server with an invalid gateway IP" do
      {socket, _} = ChannelSetup.create_socket()
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, destination_ip)

      params = %{
        "gateway_ip" => destination_ip,
        "password" => destination.password
      }

      assert {:error, reason} = join(socket, topic, params)
      assert reason.data == "server_bad_owner"
    end

    test "can start connection with a remote server" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()
      {destination, %{entity: destination_entity}} = ServerSetup.server()

      gateway_entity_id = socket.assigns.entity_id
      destination_entity_id = destination_entity.entity_id

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, destination_ip, 0)

      params = %{
        "gateway_ip" => gateway_ip,
        "password" => destination.password
      }

      assert {:ok, bootstrap, new_socket} = join(socket, topic, params)

      # `gateway` data is correct
      assert new_socket.assigns.gateway.server_id == gateway.server_id
      assert new_socket.assigns.gateway.ip == gateway_ip
      assert new_socket.assigns.gateway.entity_id == gateway_entity_id

      # `destination` data is correct
      assert new_socket.assigns.destination.server_id == destination.server_id
      assert new_socket.assigns.destination.ip == destination_ip
      assert new_socket.assigns.destination.entity_id == destination_entity_id

      # Metadata is correct
      assert new_socket.assigns.meta.access_type == :remote
      assert new_socket.assigns.meta.network_id == network_id

      # Other stuff
      assert new_socket.assigns.tunnel.tunnel_id
      assert new_socket.joined
      assert new_socket.topic == topic

      # It returned the server bootstrap
      assert bootstrap.data.filesystem
      assert bootstrap.data.logs
      assert bootstrap.data.processes

      # Keys below only exist on gateway bootstrap
      refute Map.has_key?(bootstrap.data, :password)
      refute Map.has_key?(bootstrap.data, :name)

      CacheHelper.sync_test()
    end
  end

  describe "Channel counter" do
    test "joins all servers when sequence is valid" do
      {socket, %{server: gateway1}} = ChannelSetup.create_socket()
      {gateway2, _} = ServerSetup.server(entity_id: socket.assigns.entity_id)
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      gateway1_ip = ServerQuery.get_ip(gateway1.server_id, network_id)
      gateway2_ip = ServerQuery.get_ip(gateway2.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic1 = ChannelHelper.server_topic_name(network_id, destination_ip, 0)
      topic2 = ChannelHelper.server_topic_name(network_id, destination_ip, 1)

      params1 = %{
        "gateway_ip" => gateway1_ip,
        "password" => destination.password
      }
      params2 = %{
        "gateway_ip" => gateway2_ip,
        "password" => destination.password
      }

      assert {:ok, _, socket1} = join(socket, topic1, params1)
      assert {:ok, _, socket2} = join(socket, topic2, params2)

      assert socket1.assigns.meta.counter == 0
      assert socket2.assigns.meta.counter == 1
    end

    test "fails if sequence is repeated" do
      {socket, %{server: gateway1}} = ChannelSetup.create_socket()
      {gateway2, _} = ServerSetup.server(entity_id: socket.assigns.entity_id)
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      gateway1_ip = ServerQuery.get_ip(gateway1.server_id, network_id)
      gateway2_ip = ServerQuery.get_ip(gateway2.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic1 = ChannelHelper.server_topic_name(network_id, destination_ip, 0)
      topic2 = ChannelHelper.server_topic_name(network_id, destination_ip, 0)

      params1 = %{
        "gateway_ip" => gateway1_ip,
        "password" => destination.password
      }
      params2 = %{
        "gateway_ip" => gateway2_ip,
        "password" => destination.password
      }

      assert {:ok, _, _} = join(socket, topic1, params1)
      assert {:error, reason} = join(socket, topic2, params2)
      assert reason == %{data: "bad_counter"}

      # Also fails if tries to connect same server, with the same counter, twice
      assert {:error, _} = join(socket, topic2, params1)
      assert {:error, _} = join(socket, topic1, params1)
    end

    test "counter is optional" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()

      # Note that this test must happen with remote joins only, since counters
      # are ignored at local/gateway servers joins.
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      # We haven't specified the counter at the topic name
      topic = "server:" <> to_string(network_id) <> "@" <> destination_ip
      params = %{
        "gateway_ip" => gateway_ip,
        "password" => destination.password
      }

      # Yet, it joined successfully and Helix automatically grabbed the
      # expected counter.
      assert {:ok, _, new_socket} = join(socket, topic, params)
      assert new_socket.assigns.meta.counter == 0

      # Let's do it again
      {gateway2, _} = ServerSetup.server(entity_id: socket.assigns.entity_id)

      gateway2_ip = ServerQuery.get_ip(gateway2.server_id, network_id)
      params2 = %{
        "gateway_ip" => gateway2_ip,
        "password" => destination.password
      }

      # Now the next expected counter is 1, since we are joining for the second
      # time in a row.
      assert {:ok, _, new_socket2} = join(socket, topic, params2)
      assert new_socket2.assigns.meta.counter == 1
    end

    test "fails if given counter is not next in sequence" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()
      {destination, _} = ServerSetup.server()

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)
      destination_ip = ServerQuery.get_ip(destination.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, destination_ip, 666)

      params = %{
        "gateway_ip" => gateway_ip,
        "password" => destination.password
      }

      assert {:error, reason} = join(socket, topic, params)
      assert reason == %{data: "bad_counter"}
    end

    test "ignores counter on local joins" do
      {socket, %{server: gateway}} = ChannelSetup.create_socket()

      network_id = @internet_id
      gateway_ip = ServerQuery.get_ip(gateway.server_id, network_id)

      topic = ChannelHelper.server_topic_name(network_id, gateway_ip, 666)

      assert {:ok, _, socket} = join(socket, topic, %{})
      assert socket.assigns.meta.counter == 0
    end
  end

  describe "ServerWebsocketChannelState" do
    test "Joining channel updates state (gateway)" do
      {socket, %{gateway: gateway, gateway_ip: gateway_ip}} =
        ChannelSetup.join_server(own_server: true)

      entity_id = socket.assigns.gateway.entity_id
      server_id = gateway.server_id

      # Checking Server table
      assert state_server = ServerStateHelper.lookup_server(server_id)
      state_server = ServerStateHelper.cast_server_entry(state_server)

      assert state_server.server_id == gateway.server_id

      state_channel = find_state_channel(state_server, gateway_ip)
      assert state_channel.network_id == @internet_id
      assert state_channel.ip == gateway_ip
      assert state_channel.counter == 0

      # Checking Entity table
      assert state_entity = ServerStateHelper.lookup_entity(entity_id)
      state_entity = ServerStateHelper.cast_entity_entry(state_entity)

      assert state_entity.entity_id == entity_id

      state_server = find_state_server(state_entity, server_id)

      assert state_server.server_id == server_id
      assert state_server.network_id == @internet_id
      assert state_server.ip == gateway_ip
      assert state_server.counter == 0
    end

    test "joining channel updates state (remote)" do
      {
        socket,
        %{
          gateway: gateway,
          destination: destination,
          destination_ip: destination_ip
        }
      } = ChannelSetup.join_server()

      gateway_id = gateway.server_id
      destination_id = destination.server_id
      gateway_entity_id = socket.assigns.gateway.entity_id
      destination_entity_id = socket.assigns.destination.entity_id

      # Gateway owner has a valid entry on Entity table
      assert state_entity = ServerStateHelper.lookup_entity(gateway_entity_id)
      state_entity = ServerStateHelper.cast_entity_entry(state_entity)

      # Which has correct data on it
      state_server = find_state_server(state_entity, destination_id)
      assert state_server.ip == destination_ip

      # Destination entity is completely unaffected
      refute ServerStateHelper.lookup_entity(destination_entity_id)

      # Destination server was mapped into the Server table
      assert state_server = ServerStateHelper.lookup_server(destination_id)

      state_server = ServerStateHelper.cast_server_entry(state_server)
      assert state_server.server_id == destination_id

      # Gateway server is completely unaffected
      refute ServerStateHelper.lookup_server(gateway_id)
    end

    test "leaving channel updates state (gateway)" do
      {socket, %{account: account, gateway: gateway}} =
        ChannelSetup.join_server(own_server: true)

      # Simulates user closing the channel
      :ok = close(socket)

      # Entity no longer exists on the Entity table
      refute ServerStateHelper.lookup_entity(account.account_id)

      # Notice that the Server table still has the server data, that's because
      # purging unused servers is asynchronous and happens as a background job
      assert _something = ServerStateHelper.lookup_server(gateway.server_id)
    end

    test "leaving channel updates state (remote)" do
      {socket, %{destination: destination}} = ChannelSetup.join_server()

      destination_id = destination.server_id
      destination_entity_id = socket.assigns.destination.entity_id

      # Simulates user closing the channel
      :ok = close(socket)

      # Destination entity no longer exists
      refute ServerStateHelper.lookup_entity(destination_entity_id)

      # Notice that the Server table still has the server data, that's because
      # purging unused servers is asynchronous and happens as a background job
      assert _something = ServerStateHelper.lookup_server(destination_id)
    end

    defp find_state_server(entity_state, server_id),
      do: Enum.find(entity_state.servers, &(&1.server_id == server_id))

    defp find_state_channel(server_state, ip),
      do: Enum.find(server_state.channels, &(&1.ip == ip))
  end
end
