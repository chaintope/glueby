module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        autoload :SimpleTxBuilder, 'glueby/contract/timestamp/tx_builder/simeple_tx_builder'
        autoload :TrackableTxBuilder, 'glueby/contract/timestamp/tx_builder/trackable_tx_builder'
        autoload :UpdatingTrackableTxBuilder, 'glueby/contract/timestamp/tx_builder/updating_trackable_tx_builder'

        # A transaction input to update trackable timestamp must placed at this index in the tx inputs.
        PAY_TO_CONTRACT_INPUT_INDEX = 0
      end
    end
  end
end