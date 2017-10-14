defmodule Helix.Server.Websocket.Channel.Server.Requests.PFTP do

  use Helix.Test.Case.Integration

  import Phoenix.ChannelTest

  alias Helix.Software.Model.PublicFTP
  alias Helix.Software.Query.PublicFTP, as: PublicFTPQuery

  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "pftp.server.enable" do
    test "enables a server" do
      {socket, %{gateway: server}} = ChannelSetup.join_server(own_server: true)

      # I have no PublicFTP server :(
      refute PublicFTPQuery.fetch_server(server)

      # Make the request
      ref = push socket, "pftp.server.enable", %{}

      # Wait for the response, which is empty (but :ok)
      assert_reply ref, :ok, response
      assert response.data == %{}

      # I have a PublicFTP server :)
      assert PublicFTPQuery.fetch_server(server)
    end
  end

  describe "pftp.server.disable" do
    test "disables a server" do
      {socket, %{gateway: server}} = ChannelSetup.join_server(own_server: true)
      SoftwareSetup.pftp(server_id: server.server_id)

      # I have a PFTP server
      assert PublicFTPQuery.fetch_server(server)

      # Make the request
      ref = push socket, "pftp.server.disable", %{}

      # Wait for the response, which is empty (but :ok)
      assert_reply ref, :ok, response
      assert response.data == %{}

      # My PFTP server is now disabled
      assert %PublicFTP{is_active: false} = PublicFTPQuery.fetch_server(server)
    end
  end

  describe "pftp.file.add" do
    test "adds a file" do
      {socket, %{gateway: server}} = ChannelSetup.join_server(own_server: true)
      {file, _} = SoftwareSetup.file(server_id: server.server_id)
      SoftwareSetup.pftp(server_id: server.server_id)

      params = %{
        "file_id": to_string(file.file_id)
      }

      ref = push socket, "pftp.file.add", params

      assert_reply ref, :ok, response
      assert response.data == %{}

      [entry] = PublicFTPQuery.list_files(server)
      assert entry == file
    end
  end

  describe "pftp.file.remove" do
    test "removes a file" do
      {socket, %{gateway: server}} = ChannelSetup.join_server(own_server: true)
      SoftwareSetup.pftp(server_id: server.server_id)
      {_, %{file: file}} = SoftwareSetup.pftp_file(server_id: server.server_id)

      # The file exists
      assert PublicFTPQuery.fetch_file(file)

      params = %{
        "file_id" => to_string(file.file_id)
      }

      ref = push socket, "pftp.file.remove", params

      assert_reply ref, :ok, response
      assert response.data == %{}

      # Now it doesn't
      refute PublicFTPQuery.fetch_file(file)
    end
  end
end
