module Glueby
  module AR
    class SystemInformation < ::ActiveRecord::Base

      def self.synced_block_height
        find_by(info_key: "synced_block_number")
      end

      # Return if wallet allows to use only finalized utxo.
      # @return [Boolean] true if wallet allows to use only finalized utxo, otherwise false.
      def self.use_only_finalized_utxo?
        find_by(info_key: "use_only_finalized_utxo")&.int_value != 0
      end

      # Return default value of the utxo provider
      # @return [Integer] default value of utxo provider
      def self.utxo_provider_default_value
        find_by(info_key: "utxo_provider_default_value")&.int_value
      end

      # Return pool size of the utxo provider
      # @return [Integer] pool size of utxo provider
      def self.utxo_provider_pool_size
        find_by(info_key: "utxo_provider_pool_size")&.int_value
      end

      def int_value
        info_value.to_i
      end

    end
  end
end