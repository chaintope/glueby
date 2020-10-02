# frozen_string_literal: true

require 'securerandom'

module Glueby
  module Internal
    class Wallet
      class ActiveRecordWalletAdapter < AbstractWalletAdapter
        def create_wallet
          wallet_id = SecureRandom.hex(16)
          wallet = AR::Wallet.create(wallet_id: wallet_id)
          wallet_id
        end

        def delete_wallet(wallet_id)
          AR::Wallet.destroy_by(wallet_id: wallet_id)
        end

        def load_wallet(wallet_id)
        end

        def unload_wallet(wallet_id)
        end

        def wallets
          AR::Wallet.all.map(&:wallet_id).sort
        end

        def balance(wallet_id, only_finalized = true)
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          utxos = wallet.utxos
          utxos = utxos.where(status: :finalized) if only_finalized
          utxos.sum(&:value)
        end

        def list_unspent(wallet_id, only_finalized = true)
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          utxos = wallet.utxos
          utxos = utxos.where(status: :finalized) if only_finalized
          utxos.map do |utxo|
            {
              txid: utxo.txid,
              vout: utxo.index,
              script_pubkey: utxo.script_pubkey,
              color_id: utxo.color_id,
              amount: utxo.value,
              finalized: utxo.status == :finalized
            }
          end
        end

        def sign_tx(wallet_id, tx, prevtxs = [])
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          wallet.sign(tx)
        end

        def receive_address(wallet_id)
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          key = wallet.keys.create(purpose: :receive)
          key.address
        end

        def change_address(wallet_id)
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          key = wallet.keys.create(purpose: :change)
          key.address
        end

        def create_pubkey(wallet_id)
          wallet = AR::Wallet.find_by(wallet_id: wallet_id)
          key = wallet.keys.create(purpose: :receive)
          Tapyrus::Key.new(pubkey: key.public_key)
        end
      end
    end
  end
end
