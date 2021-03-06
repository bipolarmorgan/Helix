defmodule Helix.Universe.Bank.Event.Handler.Bank.TransferTest do

  use Helix.Test.Case.Integration

  alias Helix.Process.Public.Process, as: ProcessPublic
  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Universe.Bank.Action.Flow.BankTransfer, as: BankTransferFlow
  alias Helix.Universe.Bank.Internal.BankAccount, as: BankAccountInternal
  alias Helix.Universe.Bank.Internal.BankTransfer, as: BankTransferInternal

  alias Helix.Test.Account.Setup, as: AccountSetup
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Universe.Bank.Setup, as: BankSetup

  @relay nil

  describe "transfer_aborted/1" do
    test "life cycle" do
      amount = 100_000_000
      {acc1, _} = BankSetup.account([balance: amount])
      {acc2, _} = BankSetup.account()
      {player, %{server: gateway}} = AccountSetup.account([with_server: true])

      {tunnel, _} =
        NetworkSetup.tunnel(
          gateway_id: gateway.server_id,
          destination_id: acc1.atm_id
        )

      {:ok, process} =
        BankTransferFlow.start(
          acc1, acc2, amount, player, gateway, tunnel, @relay
        )
      transfer_id = process.data.transfer_id

      assert ProcessQuery.fetch(process)
      assert BankTransferInternal.fetch(transfer_id)
      assert 0 == BankAccountInternal.get_balance(acc1)
      assert 0 == BankAccountInternal.get_balance(acc2)

      # Kill (abort)
      ProcessPublic.kill(process, :porquesim)

      # Ensure bank data is consistent
      refute BankTransferInternal.fetch(transfer_id)
      assert amount == BankAccountInternal.get_balance(acc1)
      assert 0 == BankAccountInternal.get_balance(acc2)

      # And process no longer exists..
      refute ProcessQuery.fetch(process)

      TOPHelper.top_stop(process.gateway_id)
    end
  end
end
