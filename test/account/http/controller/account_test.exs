defmodule Helix.Account.HTTP.Controller.AccountTest do

  use Helix.Test.Case.Conn
  use Helix.Test.Case.Integration

  alias HELL.TestHelper.Random
  alias Helix.Account.Action.Session, as: SessionAction

  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "register" do
    @tag :pending
    test "creates account when input is valid", context do
      password = Random.password()
      params = %{
        "username" => Random.username(),
        "email" => Random.email(),
        "password" => password
      }

      response =
        context.conn
        |> post(api_v1_account_path(context.conn, :register), params)
        |> json_response(200)

      assert is_binary(response["account_id"])
    end
  end

  describe "login" do
    test "returns bearer token on success", context do
      password = "omg i am so criative with passwords"
      account = AccountSetup.account!(password: password)

      params = %{"username" => account.username, "password" => password}

      response =
        context.conn
        |> post(api_v1_account_path(context.conn, :login), params)
        |> json_response(200)

      assert Map.has_key?(response, "token")
      assert {:ok, _, _} = SessionAction.validate_token(response["token"])
    end
  end
end
