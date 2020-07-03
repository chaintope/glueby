module Glueby
  module Contract
    module Errors
      class InsufficientFunds < StandardError; end
      class TxAlreadyBroadcasted < StandardError; end
    end
  end
end
