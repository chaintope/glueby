module Glueby
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Glueby::Contract::Timestamp::Util
        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }

        # @param [Hash] attributes attributes which consist of:
        # - wallet_id
        # - content
        # - prefix(optional)
        def initialize(attributes = nil)
          @content_hash = Tapyrus.sha256(attributes[:content]).bth
          super(wallet_id: attributes[:wallet_id], content_hash: @content_hash,
                prefix: attributes[:prefix] ? attributes[:prefix] : '', status: :init)
        end
      end
    end
  end
end
