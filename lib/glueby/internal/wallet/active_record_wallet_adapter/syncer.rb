module Glueby
  module Internal
    class Wallet
      class ActiveRecordWalletAdapter
        class Syncer
          def tx_sync(tx)
            Glueby::Internal::Wallet::AR::Utxo.destroy_for_inputs(tx)
            Glueby::Internal::Wallet::AR::Utxo.create_or_update_for_outputs(tx)
          end
        end
      end
    end
  end
end