module Glueby
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Glueby::Contract::Timestamp::Util
        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }

        # @param [String] wallet_id hex string which represents identifier of a wallet
        # @param [String] content Data to be hashed and stored in blockchain.
        # @param [String] prefix prefix of op_return data
        def initialize(wallet_id:, content:, prefix: '')
          @content_hash = Tapyrus.sha256(content).bth
          super(wallet_id: wallet_id, content_hash: @content_hash, prefix: prefix, status: :init)
        end
      end
    end
  end
end
