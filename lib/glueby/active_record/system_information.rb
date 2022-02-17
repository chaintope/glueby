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


      # Set use_only_finalized_utxo
      # @param [Boolean] status status of whether to use only finalized utxo
      def self.set_use_only_finalized_utxo(status)
        current = find_by(info_key: "use_only_finalized_utxo")
        if current
          current.update!(info_value: boolean_to_string(status))
        else
          create!(
            info_key: "use_only_finalized_utxo", 
            info_value: boolean_to_string(status)
          )
        end
      end

      # Return default value of the utxo provider
      # @return [Integer] default value of utxo provider
      def self.utxo_provider_default_value
        find_by(info_key: "utxo_provider_default_value")&.int_value
      end

      # Set utxo_provider_default_value
      # @param [Integer] value default value for utxo provider
      def self.set_utxo_provider_default_value(value)
        current = find_by(info_key: "utxo_provider_default_value")
        if current
          current.update!(info_value: value)
        else
          create!(
            info_key: "utxo_provider_default_value", 
            info_value: value
          )
        end
      end

      # Return pool size of the utxo provider
      # @return [Integer] pool size of utxo provider
      def self.utxo_provider_pool_size
        find_by(info_key: "utxo_provider_pool_size")&.int_value
      end

      # Set utxo_provider_pool_size
      # @param [Integer] size pool size of the utxo provider
      def self.set_utxo_provider_pool_size(size)
        current = find_by(info_key: "utxo_provider_pool_size")
        if current
          current.update!(info_value: size)
        else
          create!(
            info_key: "utxo_provider_pool_size", 
            info_value: size
          )
        end
      end

      # If return timestamp is to be executed immediately
      # @return [Boolean] true status of broadcast_on_background
      def self.broadcast_on_background?
        find_by(info_key: "broadcast_on_background")&.int_value != 0
      end

      # Set the status of broadcast_on_background
      # @param [Boolean] status status of broadcast_on_background
      def self.set_broadcast_on_background(status)
        current = find_by(info_key: "broadcast_on_background")
        if current
         current.update!(info_value: boolean_to_string(status))
        else
          create!(
            info_key: "broadcast_on_background", 
            info_value: boolean_to_string(status)
          )
        end
      end

      def int_value
        info_value.to_i
      end

      private

      def self.boolean_to_string(status)
        status ? "1" : "0"
      end

    end
  end
end