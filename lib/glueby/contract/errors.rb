module Glueby
  module Contract
    module Errors
      class InsufficientFunds < StandardError; end
      class InsufficientTokens < StandardError; end
      class InvalidAmount < StandardError; end
      class InvalidTokenType < StandardError; end
      class TxAlreadyBroadcasted < StandardError; end
      class UnsupportedTokenType < StandardError; end
      class UnknownScriptPubkey < StandardError; end
      class UnsupportedDigestType < StandardError; end
    end
  end
end
