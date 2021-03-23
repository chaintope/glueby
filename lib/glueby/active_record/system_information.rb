module Glueby
  module AR
    class SystemInformation < ::ActiveRecord::Base

      def self.synced_block_height
        SystemInformation.find_by(info_key: "synced_block_number")
      end

    end
  end
end