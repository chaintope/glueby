# frozen_string_literal: true

module Glueby
  class Wallet
    attr_reader :internal_wallet

    class << self
      def create
        new(Glueby::Internal::Wallet.create)
      end

      def load(wallet_id)
        new(Glueby::Internal::Wallet.load(wallet_id))
      end

      # @deprecated - Use Glueby.configure instead
      def configure(config)
        case config[:adapter]
        when 'core'
          Glueby::Internal::RPC.configure(config)
          Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::TapyrusCoreWalletAdapter.new
        when 'activerecord'
          Glueby::Internal::RPC.configure(config)
          Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
        when 'mysql'
          Glueby::Internal::RPC.configure(config)
          Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::MySQLWalletAdapter.new
        else
          raise 'Not implemented'
        end
      end
    end

    def id
      @internal_wallet.id
    end

    # @return [HashMap] hash of balances which key is color_id or empty string, and value is amount
    def balances(only_finalized = true)
      utxos = @internal_wallet.list_unspent(nil, only_finalized)
      utxos.inject({}) do |balances, output|
        key = output[:color_id] || ''
        balances[key] ||= 0
        balances[key] += output[:amount]
        balances
      end
    end

    def token_utxos(color_id = nil, only_finalized = true, page = 1, per = 25)
      @internal_wallet.list_unspent_with_count(color_id, only_finalized, nil, page, per)
    end

    private

    def initialize(internal_wallet)
      @internal_wallet = internal_wallet
    end
  end
end
