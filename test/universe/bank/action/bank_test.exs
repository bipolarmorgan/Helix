defmodule Helix.Universe.Bank.Action.BankTest do

  use Helix.Test.IntegrationCase

  import Helix.Test.IDCase

  alias HELL.TestHelper.Random
  alias HELL.TestHelper.Setup
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Universe.Bank.Action.Bank, as: BankAction
  alias Helix.Universe.Bank.Internal.BankAccount, as: BankAccountInternal
  alias Helix.Universe.Bank.Internal.BankTransfer, as: BankTransferInternal
  alias Helix.Universe.Bank.Query.Bank, as: BankQuery

  alias HELL.TestHelper.Setup
  alias Helix.Universe.NPC.Helper, as: NPCHelper

  describe "start_transfer/4" do
    test "with valid data" do
      amount = 500
      acc1 = Setup.bank_account([balance: amount])
      acc2 = Setup.bank_account()
      {_, player} = Setup.server()

      assert {:ok, transfer} =
        BankAction.start_transfer(acc1, acc2, amount, player)

      assert BankTransferInternal.fetch(transfer)
      assert 0 == BankAccountInternal.get_balance(acc1)
      assert 0 == BankAccountInternal.get_balance(acc2)
    end

    test "with insufficient funds" do
      amount = 500
      acc1 = Setup.bank_account([balance: 100])
      acc2 = Setup.bank_account()
      {_, player} = Setup.server()

      assert {:error, {:funds, :insufficient}} =
        BankAction.start_transfer(acc1, acc2, amount, player)

      assert 100 == BankAccountInternal.get_balance(acc1)
      assert 0 == BankAccountInternal.get_balance(acc2)
    end
  end

  describe "complete_transfer/1" do
    test "with valid data" do
      amount = 100
      transfer = Setup.bank_transfer([amount: amount])

      assert :ok == BankAction.complete_transfer(transfer)

      account_from =
        BankQuery.fetch_account(transfer.atm_from, transfer.account_from)
      account_to =
        BankQuery.fetch_account(transfer.atm_to, transfer.account_to)

      refute BankTransferInternal.fetch(transfer)
      assert 0 == BankAccountInternal.get_balance(account_from)
      assert amount == BankAccountInternal.get_balance(account_to)
    end

    test "with invalid data" do
      assert {:error, reason} = BankAction.complete_transfer(Random.pk())
      assert reason == {:transfer, :notfound}
    end
  end

  describe "abort_transfer/1" do
    test "with valid data" do
      amount = 100
      transfer = Setup.bank_transfer([amount: amount])

      assert :ok == BankAction.abort_transfer(transfer)

      account_from =
        BankQuery.fetch_account(transfer.atm_from, transfer.account_from)
      account_to =
        BankQuery.fetch_account(transfer.atm_to, transfer.account_to)

      refute BankTransferInternal.fetch(transfer)
      assert amount == BankAccountInternal.get_balance(account_from)
      assert 0 == BankAccountInternal.get_balance(account_to)
    end

    test "with invalid data" do
      fake_transfer = Setup.fake_bank_transfer()
      assert {:error, reason} = BankAction.abort_transfer(fake_transfer)
      assert {:transfer, :notfound} == reason
    end
  end

  describe "open_account/2" do
    test "default case" do
      {_, player} = Setup.server()
      bank = NPCHelper.bank()
      atm =
        NPCHelper.bank()
        |> Map.get(:servers)
        |> Enum.random()
        |> Map.get(:id)
        |> ServerQuery.fetch()

      assert {:ok, acc} = BankAction.open_account(player, atm)

      assert acc.account_number
      assert acc.owner_id == player.account_id
      assert acc.atm_id == atm.server_id
      assert_id acc.bank_id, bank.id
      assert 0 == acc.balance
    end
  end

  describe "close_account/1" do
    test "it closes the account" do
      acc = Setup.bank_account()

      assert BankAccountInternal.fetch(acc.atm_id, acc.account_number)
      assert :ok == BankAction.close_account(acc)
      refute BankAccountInternal.fetch(acc.atm_id, acc.account_number)
    end

    test "it refuses to close non-empty accounts" do
      acc = Setup.bank_account([balance: 1])

      assert BankAccountInternal.fetch(acc.atm_id, acc.account_number)
      assert {:error, reason} = BankAction.close_account(acc)
      assert {:account, :notempty} == reason
      assert BankAccountInternal.fetch(acc.atm_id, acc.account_number)
    end

    test "with invalid data" do
      fake_acc = Setup.fake_bank_account()
      assert {:error, reason} = BankAction.close_account(fake_acc)
      assert {:account, :notfound} == reason
    end
  end
end
