require 'active_record'

module Glueby
  module Contract
    module AR
      autoload :ReissuableToken, 'glueby/contract/active_record/reissuable_token'
      autoload :Timestamp, 'glueby/contract/active_record/timestamp'
    end
  end
end
