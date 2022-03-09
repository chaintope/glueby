module Glueby
  module Contract
    # Timestamp feature allows users to send transaction with op_return output which has sha256 hash of arbitary data.
    # Timestamp transaction has
    # * 1 or more inputs enough to afford transaction fee.
    # * 1 output which has op_return, application specific prefix, and sha256 hash of data.
    # * 1 output to send the change TPC back to the wallet.
    #
    # Storing timestamp transaction to the blockchain enables everyone to verify that the data existed at that time and a user signed it.
    class Timestamp
      P2C_DEFAULT_VALUE = 1_000

      autoload :Syncer, 'glueby/contract/timestamp/syncer'
      autoload :TxBuilder, 'glueby/contract/timestamp/tx_builder'

      attr_reader :tx, :txid
      # p2c_address and payment_base is used in `trackable` type
      attr_reader :p2c_address, :payment_base

      # @param [Gleuby::Wallet] wallet The wallet that is sender of the timestamp transaction.
      # @param [String] content Data to be hashed and stored in blockchain.
      # @param [String] prefix prefix of op_return data
      # @param [Glueby::Contract::FeeEstimator] fee_estimator
      # @param [Symbol] digest type which select of:
      # - :sha256
      # - :double_sha256
      # - :none
      # @param [Symbol] timestamp_type
      # - :simple
      # - :trackable
      # @param [Integer] prev_timestamp_id The id column of glueby_timestamps that will be updated by the timestamp that will be created
      # @raise [Glueby::Contract::Errors::UnsupportedDigestType] if digest is unsupported
      # @raise [Glueby::Contract::Errors::InvalidTimestampType] if timestamp_type is unsupported
      def initialize(
        wallet:,
        content:,
        prefix: '',
        fee_estimator: Glueby::Contract::FeeEstimator::Fixed.new,
        digest: :sha256,
        utxo_provider: nil,
        timestamp_type: :simple,
        prev_timestamp_id: nil
      )
        @wallet = wallet
        @content = content
        @prefix = prefix
        @fee_estimator = fee_estimator
        raise Glueby::Contract::Errors::UnsupportedDigestType, "#{digest} is invalid digest, supported digest are :sha256, :double_sha256, and :none."  unless [:sha256, :double_sha256, :none].include?(digest)
        @digest = digest
        @utxo_provider = utxo_provider
        raise Glueby::Contract::Errors::InvalidTimestampType, "#{timestamp_type} is invalid type, supported types are :simple, and :trackable." unless [:simple, :trackable].include?(timestamp_type)
        @timestamp_type = timestamp_type
        @prev_timestamp_id = prev_timestamp_id
      end

      # broadcast to Tapyrus Core
      # @return [String] txid
      # @raise [Glueby::Contract::Errors::TxAlreadyBroadcasted] if tx has been broadcasted.
      # @raise [Glueby::Contract::Errors::InsufficientFunds] if result of listunspent is not enough to pay the specified amount
      def save!
        raise Glueby::Contract::Errors::TxAlreadyBroadcasted if @ar

        @ar = Glueby::Contract::AR::Timestamp.new(
          wallet_id: @wallet.id,
          prefix: @prefix,
          content: @content,
          timestamp_type: @timestamp_type,
          digest: @digest,
          prev_id: @prev_timestamp_id
        )
        @ar.save_with_broadcast!(fee_estimator: @fee_estimator, utxo_provider: @utxo_provider)
        @ar.txid
      end

      def txid
        raise Glueby::Error, 'The timestamp tx is not broadcasted yet.' unless @ar
        @ar.txid
      end

      def tx
        raise Glueby::Error, 'The timestamp tx is not broadcasted yet.' unless @ar
        @ar.tx
      end

      def p2c_address
        raise Glueby::Error, 'The timestamp tx is not broadcasted yet.' unless @ar
        @ar.p2c_address
      end

      def payment_base
        raise Glueby::Error, 'The timestamp tx is not broadcasted yet.' unless @ar
        @ar.payment_base
      end
    end
  end
end
