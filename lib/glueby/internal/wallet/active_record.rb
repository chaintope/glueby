# frozen_string_literal: true

require 'active_record'

module Glueby
  module Internal
    class Wallet
      module AR
        autoload :Key, 'glueby/internal/wallet/active_record/key'
        autoload :Utxo, 'glueby/internal/wallet/active_record/utxo'
        autoload :Wallet, 'glueby/internal/wallet/active_record/wallet'
      end
    end
  end
end
