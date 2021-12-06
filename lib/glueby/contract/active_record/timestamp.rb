module Glueby
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Glueby::Contract::Timestamp::Util
        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }
        enum timestamp_type: { simple: 0, trackable: 1 }

        # @param [Hash] attributes attributes which consist of:
        # - wallet_id
        # - content
        # - prefix(optional)
        # - timestamp_type(optional)
        def initialize(attributes = nil)
          @content_hash = Tapyrus.sha256(attributes[:content]).bth
          super(wallet_id: attributes[:wallet_id], content_hash: @content_hash,
                prefix: attributes[:prefix] ? attributes[:prefix] : '', status: :init, timestamp_type: attributes[:timestamp_type] || :simple)
        end
      end
    end
  end
end
