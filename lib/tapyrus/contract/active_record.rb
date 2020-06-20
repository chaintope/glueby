require 'active_record'

module Tapyrus
  module Contract
    module AR
      autoload :Timestamp, 'tapyrus/contract/active_record/timestamp'
      autoload :Account, 'tapyrus/contract/active_record/Account'
      autoload :Address, 'tapyrus/contract/active_record/Address'
    end
  end
end
