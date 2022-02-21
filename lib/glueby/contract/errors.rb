module Glueby
  module Contract
    module Errors
      class InsufficientFunds < Error; end
      class InsufficientTokens < Error; end
      class TxAlreadyBroadcasted < Error; end
      class FailedToBroadcast < Error; end

      # Argument Errors
      class InvalidAmount < ArgumentError; end
      class InvalidSplit < ArgumentError; end
      class InvalidTokenType < ArgumentError; end
      class InvalidTimestampType < ArgumentError; end
      class UnsupportedTokenType < ArgumentError; end
      class UnknownScriptPubkey < ArgumentError; end
      class UnsupportedDigestType < ArgumentError; end
    end
  end
end
