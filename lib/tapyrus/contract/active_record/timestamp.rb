module Tapyrus
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Tapyrus::Contract::Timestamp::Util
        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }

        # @param [String] content Data to be hashed and stored in blockchain.
        # @param [String] prefix prefix of op_return data
        def initialize(content:, prefix: '')
          @content_hash = Tapyrus.sha256(content).bth
          super(content_hash: @content_hash, prefix: prefix, status: :init)
        end
      end
    end
  end
end
