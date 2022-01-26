module Glueby
  module AR
    class SystemInformation < ::ActiveRecord::Base

      def self.synced_block_height
        SystemInformation.find_by(info_key: "synced_block_number")
      end

      # Return if wallet allows to use only finalized utxo.
      # @return [Boolean] true if wallet allows to use only finalized utxo, otherwise false.
      def self.use_only_finalized_utxo?
        SystemInformation.find_by(info_key: "use_only_finalized_utxo")&.int_value != 0
      end

      def int_value
        info_value.to_i
      end

    end
  end
end