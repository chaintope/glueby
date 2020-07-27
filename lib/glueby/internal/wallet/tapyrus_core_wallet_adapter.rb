# frozen_string_literal: true

require 'securerandom'
require 'bigdecimal'

module Glueby
  module Internal
    class Wallet
      class TapyrusCoreWalletAdapter < AbstractWalletAdapter
        WALLET_PREFIX = 'wallet-'
        ADDRESS_TYPE = 'legacy'

        RPC_WALLET_NOT_FOUND_ERROR_CODE = -18

        def create_wallet
          wallet_id = SecureRandom.hex(32)
          RPC.client.createwallet(wallet_name(wallet_id))
          wallet_id
        end

        # On TapyrusCoreWallet, there are no way to delete real wallet via RPC.
        # So, here just unload.
        def delete_wallet(wallet_id)
          unload_wallet(wallet_id)
        end

        def load_wallet(wallet_id)
          RPC.client.loadwallet(wallet_name(wallet_id))
        end

        def unload_wallet(wallet_id)
          RPC.client.unloadwallet(wallet_name(wallet_id))
        end

        def wallets
          RPC.client.listwallets.map do |wallet_name|
            match = /\A#{WALLET_PREFIX}(?<wallet_id>[0-9A-Fa-f]{64})\z/.match(wallet_name)
            next unless match

            match[:wallet_id]
          end.compact
        end

        def balance(wallet_id, only_finalized = true)
          perform_as(wallet_id) do |client|
            confirmed = tpc_to_tapyrus(client.getbalance)
            return confirmed if only_finalized

            confirmed + tpc_to_tapyrus(client.getunconfirmedbalance)
          end
        end

        def list_unspent(wallet_id, only_finalized = true)
          perform_as(wallet_id) do |client|
            min_conf = only_finalized ? 1 : 0
            res = client.listunspent(min_conf)

            res.map do |i|
              {
                txid: i['txid'],
                vout: i['vout'],
                amount: tpc_to_tapyrus(i['amount']),
                finalized: i['confirmations'] != 0
              }
            end
          end
        end

        def sign_tx(wallet_id, tx)
          perform_as(wallet_id) do |client|
            res = client.signrawtransactionwithwallet(tx.to_hex)
            if res['complete']
              Tapyrus::Tx.parse_from_payload(res['hex'].htb)
            else
              raise res['errors'].to_json
            end
          end
        end

        def receive_address(wallet_id)
          perform_as(wallet_id) do |client|
            client.getnewaddress('', ADDRESS_TYPE)
          end
        end

        def change_address(wallet_id)
          perform_as(wallet_id) do |client|
            client.getrawchangeaddress(ADDRESS_TYPE)
          end
        end

        def create_pubkey(wallet_id)
          perform_as(wallet_id) do |client|
            address = client.getnewaddress('', ADDRESS_TYPE)
            info = client.getaddressinfo(address)
            Tapyrus::Key.new(pubkey: info['pubkey'])
          end
        end

        private

        def perform_as(wallet_id)
          RPC.perform_as(wallet_name(wallet_id)) do |client|
            begin
              yield(client)
            rescue RuntimeError => ex
              if /"code"=>#{RPC_WALLET_NOT_FOUND_ERROR_CODE}/ =~ ex.message
                raise Errors::WalletUnloaded, "The wallet #{wallet_id} is unloaded. You should load before use it."
              else
                raise ex
              end
            end
          end
        end

        def wallet_name(wallet_id)
          "#{WALLET_PREFIX}#{wallet_id}"
        end

        # Convert TPC to tapyrus. 1 TPC is 10**8 tapyrus.
        # @param [String] tpc
        # @return [Integer] tapyrus
        #
        # Example) "0.00000010" to 10.
        def tpc_to_tapyrus(tpc)
          (BigDecimal(tpc) * 10**8).to_i
        end
      end
    end
  end
end
