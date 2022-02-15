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

      # 
      def self.set_use_only_finalized_utxo(status)
        if column_names.include? "use_only_finalized_utxo"
          current = find_by(info_key: "use_only_finalized_utxo")
          current.update!(info_value: status)
        else
          create!(
            info_key: "use_only_finalized_utxo", 
            info_value: status
          )
        end
      end

      # Return default value of the utxo provider
      # @return [Integer] default value of utxo provider
      def self.utxo_provider_default_value
        find_by(info_key: "utxo_provider_default_value")&.int_value
      end

      # 
      def self.set_utxo_provider_default_value(value)
        if column_names.include? "utxo_provider_default_value"
          current = find_by(info_key: "utxo_provider_default_value")
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

      # 
      def self.set_utxo_provider_pool_size(size)
        if column_names.include? "utxo_provider_pool_size"
          current = find_by(info_key: "utxo_provider_pool_size")
          current.update!(info_value: size)
        else
          create!(
            info_key: "utxo_provider_pool_size", 
            info_value: size
          )
        end
      end

      # 
      # @return [Boolean] true 
      def self.broadcast_on_background?
        find_by(info_key: "broadcast_on_background")&.int_value != 0
      end

      # 
      def self.set_broadcast_on_background(status)
        if column_names.include? "broadcast_on_background"
          current = find_by(info_key: "broadcast_on_background")
          current.update!(info_value: status)
        else
          create!(
            info_key: "broadcast_on_background", 
            info_value: status
          )
        end
      end

      def int_value
        info_value.to_i
      end

    end
  end
end