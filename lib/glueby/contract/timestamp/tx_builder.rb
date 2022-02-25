module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        autoload :Simple, 'glueby/contract/timestamp/tx_builder/simple'
        autoload :Trackable, 'glueby/contract/timestamp/tx_builder/trackable'
        autoload :UpdatingTrackable, 'glueby/contract/timestamp/tx_builder/updating_trackable'

        # A transaction input to update trackable timestamp must placed at this index in the tx inputs.
        PAY_TO_CONTRACT_INPUT_INDEX = 0
      end
    end
  end
end