# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      class MySQLWalletAdapter < ActiveRecordWalletAdapter
        def lock_unspent(wallet_id, utxo)
          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            record = AR::Utxo.lock("FOR UPDATE SKIP LOCKED").find_by(txid: utxo[:txid], index: utxo[:vout], status: [:init, :finalized, :broadcasted])
            record&.update!(status: :spending)
            record
          end
        end
      end
    end
  end
end
