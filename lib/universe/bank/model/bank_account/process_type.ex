import Helix.Process

process Helix.Universe.Bank.Model.BankAccount.RevealPassword.ProcessType do

  alias Helix.Universe.Bank.Model.ATM
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Universe.Bank.Model.BankToken

  process_struct [:token_id, :atm_id, :account_number]

  @process_type :bank_reveal_password

  @type t ::
    %__MODULE__{
      token_id: BankToken.id,
      atm_id: ATM.id,
      account_number: BankAccount.account
    }

  process_type do

    alias Helix.Universe.Bank.Event.RevealPassword.Processed,
      as: RevealPasswordProcessedEvent

    def dynamic_resources(_),
      do: [:cpu]

    def minimum(_),
      do: %{}

    on_completion(data) do
      event = RevealPasswordProcessedEvent.new(process, data)

      {:ok, [event]}
    end
  end
end
