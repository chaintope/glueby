module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        class Trackable < Simple
          attr_reader :p2c_address, :payment_base

          # @override
          def set_data(prefix, data)
            @prefix = prefix
            @data = data

            # Create a new trackable timestamp
            @p2c_address, @payment_base = create_pay_to_contract_address(@wallet, contents: [prefix, data])
            @txb.pay(p2c_address, P2C_DEFAULT_VALUE)
            self
          end

          private

          # TODO: Move into wallet
          # @param [Glueby::Wallet] wallet
          # @param [Array] contents The data to be used for generating pay-to-contract address
          # @return [pay-to-contract address, public key used for generating address]
          def create_pay_to_contract_address(wallet, contents: nil)
            # Calculate P + H(P || contents)G
            group = ECDSA::Group::Secp256k1
            pubkey = wallet.internal_wallet.create_pubkey.pubkey
            p = Tapyrus::Key.new(pubkey: pubkey).to_point # P
            commitment = create_pay_to_contract_commitment(pubkey, contents: contents)
            point = p + group.generator.multiply_by_scalar(commitment) # P + H(P || contents)G
            [Tapyrus::Key.new(pubkey: point.to_hex(true)).to_p2pkh, pubkey] # [p2c address, P]
          end

          # TODO: Move into wallet
          # Calculate commitment = H(P || contents)
          # @param [String] pubkey The public key hex string
          def create_pay_to_contract_commitment(pubkey, contents: nil)
            group = ECDSA::Group::Secp256k1
            p = Tapyrus::Key.new(pubkey: pubkey).to_point # P
            Tapyrus.sha256(p.to_hex(true).htb + contents.join).bth.to_i(16) % group.order # H(P || contents)
          end
        end
      end
    end
  end
end