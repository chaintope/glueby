module Glueby
  module Contract
    # Timestamp feature allows users to send transaction with op_return output which has sha256 hash of arbitary data.
    # Timestamp transaction has
    # * 1 or more inputs enough to afford transaction fee.
    # * 1 output which has op_return, application specific prefix, and sha256 hash of data.
    # * 1 output to send the change TPC back to the wallet.
    #
    # Storing timestamp transaction to the blockchain enables everyone to verify that the data existed at that time and a user signed it.
    #
    # == Versioning Timestamp
    #
    # The timestamp has an attribute called "version".
    # Version indicates how the timestamp is recorded in the blockchain. Currently, only versions 1 and 2 are supported, and each is recorded in the following manner
    # * Version 1: The first version of the blockchain is used to record timestamps.
    #     treats the content and prefix received as parameters as a binary string
    # * Version 2:.
    #     treats the specified content and prefix as a hexadecimal string with the string set to prefix and content.
    #
    # For example, when recording a simple type of timestamp, the difference between the content recorded by version 1 and version 2 is as follows
    # Version 1: 
    #   Save the timestamp as follows:
    #
    #  Glueby::Contract::Timestamp.new(
    #    wallet: wallet,
    #    content: "1234",
    #    prefix: "071222",
    #    digest: :none,
    #    version: "1"
    #  )
    #
    # The output script of the recorded transaction will include OP_RETURN and will look like this:
    #
    # OP_RETURN 30373132323231323334
    #
    # Note that prefix: "071222" and content: "1234" are interpreted as ASCII strings and their hexadecimal representation "3037313232323132323334" is recorded in the actual blockchain, respectively.
    #
    # Version 2: 
    #
    # To save the timestamp in version 2, simply change the version of the previous example to "2".
    #
    #  Glueby::Contract::Timestamp.new(
    #    wallet: wallet,
    #    content: "1234",
    #    prefix: "071222",
    #    digest: :none,
    #    version: "2"
    #  )
    #
    # The output script will look like this:
    #
    # OP_RETURN 0712221234
    #
    # In this case, prefix: "071222" and content: "1234" are treated as a hexadecimal string and recorded directly in the blockchain.
    class Timestamp
      P2C_DEFAULT_VALUE = 1_000

      autoload :Syncer, 'glueby/contract/timestamp/syncer'
      autoload :TxBuilder, 'glueby/contract/timestamp/tx_builder'

      attr_reader :tx, :txid
      # p2c_address and payment_base is used in `trackable` type
      attr_reader :p2c_address, :payment_base

      # @param [Gleuby::Wallet] wallet The wallet that is sender of the timestamp transaction.
      # @param [String] content The data to be hashed(it is due to digest argument) and stored in blockchain.
      # @param [String] prefix prefix of op_return data
      # @param [Glueby::Contract::FeeEstimator] fee_estimator
      # @param [Symbol] digest The types which will be used for process the content argument. Select of:
      # - :sha256
      # - :double_sha256
      # - :none
      # @param [Symbol] timestamp_type
      # - :simple
      # - :trackable
      # @param [Integer] prev_timestamp_id The id column of glueby_timestamps that will be updated by the timestamp that will be created
      # @param [String] version Version of the timestamp recording method.
      #     The format in which the timestamp is recorded differs depending on the version.
      #     Version "1" treats the specified content and prefix as a binary string.
      #     Version "2" treats the specified content and prefix as a hexadecimal string with the string set to prefix and content.
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
        prev_timestamp_id: nil,
        version:
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
        raise Glueby::Contract::Errors::UnsupportedTimestampVersion, "#{version} is unsupported, supported versions are '1' and '2'." unless ['1', '2'].include?(version)
        @version = version
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
          prev_id: @prev_timestamp_id,
          version: @version
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
