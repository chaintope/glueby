# frozen_string_literal: true
require 'active_record'

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
    # Issue with metadata / Get metadata
    # token = Token.issue!(issuer: alice, amount: 100, metadata: 'metadata')
    # token.metadata
    # => "metadata"
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
        # @param split [Integer] The tx outputs should be split by specified number.
        # @param fee_estimator [Glueby::Contract::FeeEstimator]
        # @param metadata [String] The data to be stored in blockchain.
        # @return [Array<token, Array<tx>>] Tuple of tx array and token object
        # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
        # @raise [InvalidAmount] if amount is not positive integer.
        # @raise [InvalidSplit] if split is greater than 1 for NFT token.
        # @raise [UnsupportedTokenType] if token is not supported.
        def issue!(issuer:, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 1, split: 1, fee_estimator: FeeEstimator::Fixed.new, metadata: nil)
          raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?
          raise Glueby::Contract::Errors::InvalidSplit if token_type == Tapyrus::Color::TokenTypes::NFT && split > 1

          txs, color_id = case token_type
                         when Tapyrus::Color::TokenTypes::REISSUABLE
                           issue_reissuable_token(issuer: issuer, amount: amount, split: split, fee_estimator: fee_estimator, metadata: metadata)
                         when Tapyrus::Color::TokenTypes::NON_REISSUABLE
                           issue_non_reissuable_token(issuer: issuer, amount: amount, split: split, fee_estimator: fee_estimator, metadata: metadata)
                         when Tapyrus::Color::TokenTypes::NFT
                           issue_nft_token(issuer: issuer, metadata: metadata)
                         else
                           raise Glueby::Contract::Errors::UnsupportedTokenType
                         end

          [new(color_id: color_id), txs]
        end

        def only_finalized?
          Glueby::AR::SystemInformation.use_only_finalized_utxo?
        end

        # Sign to pay-to-contract output.
        #
        # @param issuer [Glueby::Walelt] Issuer of the token
        # @param tx [Tapyrus::Tx] The transaction to be signed with metadata
        # @param funding_tx [Tapyrus::Tx] The funding transaction that has pay-to-contract output in its first output
        # @param payment_base [String] The public key used to generate pay to contract public key
        # @param metadata [String] Data that represents token metadata
        # @return [Tapyrus::Tx] signed tx
        def sign_to_p2c_output(issuer, tx, funding_tx, payment_base, metadata)
          utxo = { txid: funding_tx.txid, vout: 0, script_pubkey: funding_tx.outputs[0].script_pubkey.to_hex }
          issuer.internal_wallet.sign_to_pay_to_contract_address(tx, utxo, payment_base, metadata)
        end

        private

        def create_p2c_address(wallet, metadata)
          p2c_address, payment_base = wallet.internal_wallet.create_pay_to_contract_address(metadata)
          script = Tapyrus::Script.parse_from_addr(p2c_address)
          [script, p2c_address, payment_base]
        end

        def issue_reissuable_token(issuer:, amount:, split: 1, fee_estimator:, metadata: nil)
          script, p2c_address, payment_base = create_p2c_address(issuer, metadata) if metadata

          # For reissuable token, we need funding transaction for every issuance.
          # To make it easier for API users to understand whether a transaction is a new issue or a reissue, 
          # when Token.issue! is executed, a new address is created and tpc is sent to it to ensure that it is a new issue, 
          # and a transaction is created using that UTXO as input to create a new color_id. 
          funding_tx = create_funding_tx(wallet: issuer, script: script, only_finalized: only_finalized?)
          script_pubkey = funding_tx.outputs.first.script_pubkey
          color_id = Tapyrus::Color::ColorIdentifier.reissuable(script_pubkey)

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            funding_tx = issuer.internal_wallet.broadcast(funding_tx)
          end

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            # Store the script_pubkey for reissue the token.
            Glueby::Contract::AR::ReissuableToken.create!(color_id: color_id.to_hex, script_pubkey: script_pubkey.to_hex)

            tx = create_issue_tx_for_reissuable_token(funding_tx: funding_tx, issuer: issuer, amount: amount, split: split, fee_estimator: fee_estimator)
            if metadata
              Glueby::Contract::AR::TokenMetadata.create!(
                color_id: color_id.to_hex,
                metadata: metadata,
                p2c_address: p2c_address,
                payment_base: payment_base
              )
              tx = sign_to_p2c_output(issuer, tx, funding_tx, payment_base, metadata)
            end
            tx = issuer.internal_wallet.broadcast(tx)
            [[funding_tx, tx], color_id]
          end
        end

        def issue_non_reissuable_token(issuer:, amount:, split: 1, fee_estimator:, metadata: nil)
          script, p2c_address, payment_base = create_p2c_address(issuer, metadata) if metadata
          funding_tx = create_funding_tx(wallet: issuer, script: script, only_finalized: only_finalized?) if Glueby.configuration.use_utxo_provider? || script
          if funding_tx
            ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              funding_tx = issuer.internal_wallet.broadcast(funding_tx)
            end
          end

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            tx = create_issue_tx_for_non_reissuable_token(funding_tx: funding_tx, issuer: issuer, amount: amount, split: split, fee_estimator: fee_estimator)
            out_point = tx.inputs.first.out_point
            color_id = Tapyrus::Color::ColorIdentifier.non_reissuable(out_point)
            if metadata
              Glueby::Contract::AR::TokenMetadata.create!(
                color_id: color_id.to_hex,
                metadata: metadata,
                p2c_address: p2c_address,
                payment_base: payment_base
              )
              tx = sign_to_p2c_output(issuer, tx, funding_tx, payment_base, metadata)
            end
            tx = issuer.internal_wallet.broadcast(tx)

            if funding_tx
              [[funding_tx, tx], color_id]
            else
              [[tx], color_id]
            end
          end
        end

        def issue_nft_token(issuer:, metadata: nil)
          script, p2c_address, payment_base = create_p2c_address(issuer, metadata) if metadata
          funding_tx = create_funding_tx(wallet: issuer, script: script, only_finalized: only_finalized?) if Glueby.configuration.use_utxo_provider? || script
          if funding_tx
            ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              funding_tx = issuer.internal_wallet.broadcast(funding_tx)
            end
          end

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            tx = create_issue_tx_for_nft_token(funding_tx: funding_tx, issuer: issuer)
            out_point = tx.inputs.first.out_point
            color_id = Tapyrus::Color::ColorIdentifier.nft(out_point)
            if metadata
              Glueby::Contract::AR::TokenMetadata.create!(
                color_id: color_id.to_hex,
                metadata: metadata,
                p2c_address: p2c_address,
                payment_base: payment_base
              )
              tx = sign_to_p2c_output(issuer, tx, funding_tx, payment_base, metadata)
            end
            tx = issuer.internal_wallet.broadcast(tx)

            if funding_tx
              [[funding_tx, tx], color_id]
            else
              [[tx], color_id]
            end
          end
        end
      end

      attr_reader :color_id

      # Re-issue the token with specified amount.
      # A wallet can issue the token only when it is REISSUABLE token.
      # @param issuer [Glueby::Wallet]
      # @param amount [Integer]
      # @param split [Integer]
      # @param fee_estimator [Glueby::Contract::FeeEstimator]
      # @return [Array<String, tx>] Tuple of color_id and tx object
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InvalidAmount] if amount is not positive integer.
      # @raise [InvalidTokenType] if token is not reissuable.
      # @raise [UnknownScriptPubkey] when token is reissuable but it doesn't know script pubkey to issue token.
      def reissue!(issuer:, amount:, split: 1, fee_estimator: FeeEstimator::Fixed.new)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?
        raise Glueby::Contract::Errors::InvalidTokenType unless token_type == Tapyrus::Color::TokenTypes::REISSUABLE

        token_metadata = Glueby::Contract::AR::TokenMetadata.find_by(color_id: color_id.to_hex)
        raise Glueby::Contract::Errors::UnknownScriptPubkey unless valid_reissuer?(wallet: issuer, token_metadata: token_metadata)

        funding_tx = create_funding_tx(wallet: issuer, script: @script_pubkey, only_finalized: only_finalized?)
        funding_tx = issuer.internal_wallet.broadcast(funding_tx)
        tx = create_reissue_tx(funding_tx: funding_tx, issuer: issuer, amount: amount, color_id: color_id, split: split, fee_estimator: fee_estimator)
        if token_metadata
          tx = Token.sign_to_p2c_output(issuer, tx, funding_tx, token_metadata.payment_base, token_metadata.metadata)
        end
        tx = issuer.internal_wallet.broadcast(tx)

        [color_id, tx]
      end

      # Send the token to other wallet
      #
      # @param sender [Glueby::Wallet] wallet to send this token
      # @param receiver_address [String] address to receive this token
      # @param amount [Integer]
      # @param fee_estimator [Glueby::Contract::FeeEstimator]
      # @return [Array<String, tx>] Tuple of color_id and tx object
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InsufficientTokens] if wallet does not have enough token to send.
      # @raise [InvalidAmount] if amount is not positive integer.
      def transfer!(sender:, receiver_address:, amount: 1, fee_estimator: FeeEstimator::Fixed.new)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

        tx = create_transfer_tx(
          color_id: color_id,
          sender: sender,
          receiver_address: receiver_address,
          amount: amount,
          only_finalized: only_finalized?,
          fee_estimator: fee_estimator
        )
        sender.internal_wallet.broadcast(tx)
        [color_id, tx]
      end

      # Send the tokens to multiple wallets
      #
      # @param sender [Glueby::Wallet] wallet to send this token
      # @param receivers [Array<Hash>] array of hash, which keys are :address and :amount
      # @param fee_estimator [Glueby::Contract::FeeEstimator]
      # @return [Array<String, tx>] Tuple of color_id and tx object
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InsufficientTokens] if wallet does not have enough token to send.
      # @raise [InvalidAmount] if amount is not positive integer.
      def multi_transfer!(sender:, receivers:, fee_estimator: FeeEstimator::Fixed.new)
        receivers.each do |r|
          raise Glueby::Contract::Errors::InvalidAmount unless r[:amount].positive?
        end

        tx = create_multi_transfer_tx(
          color_id: color_id,
          sender: sender,
          receivers: receivers,
          only_finalized: only_finalized?,
          fee_estimator: fee_estimator
        )
        sender.internal_wallet.broadcast(tx)
        [color_id, tx]
      end

      # Burn token
      # If amount is not specified or 0, burn all token associated with the wallet.
      #
      # @param sender [Glueby::Wallet] wallet to send this token
      # @param amount [Integer]
      # @param fee_estimator [Glueby::Contract::FeeEstimator]
      # @raise [InsufficientFunds] if wallet does not have enough TPC to send transaction.
      # @raise [InsufficientTokens] if wallet does not have enough token to send transaction.
      # @raise [InvalidAmount] if amount is not positive integer.
      def burn!(sender:, amount: 0, fee_estimator: FeeEstimator::Fixed.new)
        raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?
        balance = sender.balances(only_finalized?)[color_id.to_hex]
        raise Glueby::Contract::Errors::InsufficientTokens unless balance
        raise Glueby::Contract::Errors::InsufficientTokens if balance < amount

        tx = create_burn_tx(color_id: color_id, sender: sender, amount: amount, only_finalized: only_finalized?, fee_estimator: fee_estimator)
        sender.internal_wallet.broadcast(tx)
      end

      # Return balance of token in the specified wallet.
      # @param wallet [Glueby::Wallet]
      # @return [Integer] amount of utxo value associated with this token.
      def amount(wallet:)
        # collect utxo associated with this address
        utxos = wallet.internal_wallet.list_unspent(only_finalized?)
        _, results = collect_colored_outputs(utxos, color_id)
        results.sum { |result| result[:amount] }
      end

      # Return metadata for this token
      # @return [String] metadata. if token is not associated with metadata, return nil
      def metadata
        token_metadata&.metadata
      end

      # Return pay to contract address
      # @return [String] p2c_address. if token is not associated with metadata, return nil
      def p2c_address
        token_metadata&.p2c_address
      end

      # Return public key used to generate pay to contract address
      # @return [String] payment_base. if token is not associated with metadata, return nil
      def payment_base
        token_metadata&.payment_base
      end

      # Return Glueby::Contract::AR::TokenMetadata instance for this token
      # @return [Glueby::Contract::AR::TokenMetadata]
      def token_metadata
        return @token_metadata if defined? @token_metadata
        @token_metadata = Glueby::Contract::AR::TokenMetadata.find_by(color_id: color_id.to_hex)
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

      def only_finalized?
        @only_finalized ||= Token.only_finalized?
      end

      # Verify that wallet is the issuer of the reissuable token
      # @param wallet [Glueby::Wallet]
      # @param token_metadata [Glueby::Contract::AR::TokenMetadata] metadata to be stored in blockchain as p2c address
      # @return [Boolean] true if the wallet is the issuer of this token
      def valid_reissuer?(wallet:, token_metadata: nil)
        return false unless script_pubkey&.p2pkh?
        address = if token_metadata
            payment_base = Tapyrus::Key.new(pubkey: token_metadata.payment_base, key_type: Tapyrus::Key::TYPES[:compressed])
            payment_base.to_p2pkh
          else
            script_pubkey.to_addr
          end
        wallet.internal_wallet.has_address?(address)
      end
    end
  end
end