# frozen_string_literal: true

module Glueby
  module Contract
    # This class represents custom token issued by application user.
    # Application users can
    # - issue their own tokens.
    # - send to other users.
    # - make the tokens disable.
    #
    # Examples:
    #
    # alice = Glueby::Wallet.create
    # bob = Glueby::Wallet.create
    #
    # Use `Glueby::Internal::Wallet#receive_address` to generate the address of bob
    # bob.internal_wallet.receive_address
    # => '1CY6TSSARn8rAFD9chCghX5B7j4PKR8S1a'
    #
    # Issue
    # token = Token.issue!(issuer: alice, amount: 100)
    # token.amount(wallet: alice)
    # => 100
    #
    # Send
    # token.transfer!(sender: alice, receiver_address: '1CY6TSSARn8rAFD9chCghX5B7j4PKR8S1a', amount: 1)
    # token.amount(wallet: alice)
    # => 99
    # token.amount(wallet: bob)
    # => 1
    #
    # Burn
    # token.burn!(sender: alice, amount: 10)
    # token.amount(wallet: alice)
    # => 89
    # token.burn!(sender: alice)
    # token.amount(wallet: alice)
    # => 0
    #
    # Reissue
    # token.reissue!(issuer: alice, amount: 100)
    # token.amount(wallet: alice)
    # => 100
    #
    class Token
      include Glueby::Contract::TxBuilder
      extend Glueby::Contract::TxBuilder

      class << self
        # Issue new token with specified amount and token type.
        # REISSUABLE token can be reissued with #reissue! method, and
        # NON_REISSUABLE and NFT token can not.
        # Amount is set to 1 when the token type is NFT
        #
        # @param issuer [Glueby::Wallet]
        # @param token_type [TokenTypes]
        # @param amount [Integer]
        # @return [Array<token, Array<tx>>] Tuple of tx array and token object
        # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
        # @raise [InvalidAmount] if amount is not positive integer.
        # @raise [UnspportedTokenType] if token is not supported.
        def issue!(issuer:, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 1)
          raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

          txs, color_id = case token_type
                         when Tapyrus::Color::TokenTypes::REISSUABLE
                           issue_reissuable_token(issuer: issuer, amount: amount)
                         when Tapyrus::Color::TokenTypes::NON_REISSUABLE
                           issue_non_reissuable_token(issuer: issuer, amount: amount)
                         when Tapyrus::Color::TokenTypes::NFT
                           issue_nft_token(issuer: issuer)
                         else
                           raise Glueby::Contract::Errors::UnsupportedTokenType
                         end

          [new(color_id: color_id), txs]
        end

        private

        def issue_reissuable_token(issuer:, amount:)
          funding_tx = create_funding_tx(wallet: issuer)
          script_pubkey = funding_tx.outputs.first.script_pubkey
          color_id = Tapyrus::Color::ColorIdentifier.reissuable(script_pubkey)

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            # Store the script_pubkey for reissue the token.
            Glueby::Contract::AR::ReissuableToken.create!(color_id: color_id.to_hex, script_pubkey: script_pubkey.to_hex)

            funding_tx = issuer.internal_wallet.broadcast(funding_tx)
            tx = create_issue_tx_for_reissuable_token(funding_tx: funding_tx, issuer: issuer, amount: amount)
            tx = issuer.internal_wallet.broadcast(tx)
            [[funding_tx, tx], color_id]
          end
        end

        def issue_non_reissuable_token(issuer:, amount:)
          tx = create_issue_tx_for_non_reissuable_token(issuer: issuer, amount: amount)
          tx = issuer.internal_wallet.broadcast(tx)

          out_point = tx.inputs.first.out_point
          color_id = Tapyrus::Color::ColorIdentifier.non_reissuable(out_point)
          [[tx], color_id]
        end

        def issue_nft_token(issuer:)
          tx = create_issue_tx_for_nft_token(issuer: issuer)
          tx = issuer.internal_wallet.broadcast(tx)

          out_point = tx.inputs.first.out_point
          color_id = Tapyrus::Color::ColorIdentifier.nft(out_point)
          [[tx], color_id]
        end
      end

      attr_reader :color_id

      # Re-issue the token with specified amount.
      # A wallet can issue the token only when it is REISSUABLE token.
      # @param issuer [Glueby::Wallet]
      # @param amount [Integer]
      # @return [Array<String, tx>] Tuple of color_id and tx object
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InvalidAmount] if amount is not positive integer.
      # @raise [InvalidTokenType] if token is not reissuable.
      # @raise [UnknownScriptPubkey] when token is reissuable but it doesn't know script pubkey to issue token.
      def reissue!(issuer:, amount:)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?
        raise Glueby::Contract::Errors::InvalidTokenType unless token_type == Tapyrus::Color::TokenTypes::REISSUABLE

        if validate_reissuer(wallet: issuer)
          funding_tx = create_funding_tx(wallet: issuer, script: @script_pubkey)
          funding_tx = issuer.internal_wallet.broadcast(funding_tx)
          tx = create_reissue_tx(funding_tx: funding_tx, issuer: issuer, amount: amount, color_id: color_id)
          tx = issuer.internal_wallet.broadcast(tx)

          [color_id, tx]
        else
          raise Glueby::Contract::Errors::UnknownScriptPubkey
        end
      end

      # Send the token to other wallet
      #
      # @param sender [Glueby::Wallet] wallet to send this token
      # @param receiver_address [String] address to receive this token
      # @param amount [Integer]
      # @return [Array<String, tx>] Tuple of color_id and tx object
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InsufficientTokens] if wallet does not have enough token to send.
      # @raise [InvalidAmount] if amount is not positive integer.
      def transfer!(sender:, receiver_address:, amount: 1)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

        tx = create_transfer_tx(color_id: color_id, sender: sender, receiver_address: receiver_address, amount: amount)
        sender.internal_wallet.broadcast(tx)
        [color_id, tx]
      end

      # Burn token
      # If amount is not specified or 0, burn all token associated with the wallet.
      #
      # @param sender [Glueby::Wallet] wallet to send this token
      # @param amount [Integer]
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InsufficientTokens] if wallet does not have enough token to send transaction.
      # @raise [InvalidAmount] if amount is not positive integer.
      def burn!(sender:, amount: 0)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

        tx = create_burn_tx(color_id: color_id, sender: sender, amount: amount)
        sender.internal_wallet.broadcast(tx)
      end

      # Return balance of token in the specified wallet.
      # @param wallet [Glueby::Wallet]
      # @return [Integer] amount of utxo value associated with this token.
      def amount(wallet:)
        # collect utxo associated with this address
        utxos = wallet.internal_wallet.list_unspent
        _, results = collect_colored_outputs(utxos, color_id)
        results.sum { |result| result[:amount] }
      end

      # Return token type
      # @return [Tapyrus::Color::TokenTypes]
      def token_type
        color_id.type
      end

      # Return the script_pubkey of the token from ActiveRecord
      # @return [String] script_pubkey
      def script_pubkey
        @script_pubkey ||= Glueby::Contract::AR::ReissuableToken.script_pubkey(@color_id.to_hex)
      end

      # Return serialized payload
      # @return [String] payload
      def to_payload
        payload = +''
        payload << @color_id.to_payload
        payload << @script_pubkey.to_payload if script_pubkey
        payload
      end

      # Restore token from payload
      # @param payload [String]
      # @return [Glueby::Contract::Token]
      def self.parse_from_payload(payload)
        color_id, script_pubkey = payload.unpack('a33a*')
        color_id = Tapyrus::Color::ColorIdentifier.parse_from_payload(color_id)
        if color_id.type == Tapyrus::Color::TokenTypes::REISSUABLE
          raise ArgumentError, 'script_pubkey should not be empty' if script_pubkey.empty?
          script_pubkey = Tapyrus::Script.parse_from_payload(script_pubkey)
          Glueby::Contract::AR::ReissuableToken.create!(color_id: color_id.to_hex, script_pubkey: script_pubkey.to_hex)
        end
        new(color_id: color_id)
      end

      # Generate Token Instance
      # @param color_id [String]
      def initialize(color_id:)
        @color_id = color_id
      end

      private

      # Verify that wallet is the issuer of the reissuable token
      #　reutrn [Boolean]
      def validate_reissuer(wallet:)
        addresses = wallet.internal_wallet.get_addresses
        addresses.each do |address|
          decoded_address = Tapyrus.decode_base58_address(address)
          pubkey_hash_from_address = decoded_address[0]
          pubkey_hash_from_script = Tapyrus::Script.parse_from_payload(script_pubkey.chunks[2])
          if pubkey_hash_from_address == pubkey_hash_from_script.to_s
            return true
          end
        end
        false
      end
    end
  end
end