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

    # @param [Boolean] only_finalized If true, return only finalized UTXOs
    # @param [Integer] page The number of page. If it specified, return only the page. If not specified,
    #                       return all color_ids.
    # @param [Integer] per The number of UTXOs per page.
    # @return [HashMap] hash of balances which key is color_id or empty string, and value is amount
    def balances(only_finalized = true, page: nil, per: DEFAULT_PER_PAGE)
      if page
        internal_balances(only_finalized).sort[(page - 1) * per, per].to_h
      else
        internal_balances(only_finalized)
      end
    end

    private

    def initialize(internal_wallet)
      @internal_wallet = internal_wallet
    end

    def internal_balances(only_finalized)
      utxos = @internal_wallet.list_unspent(only_finalized)
      utxos.inject({}) do |balances, output|
        key = output[:color_id] || ''
        balances[key] ||= 0
        balances[key] += output[:amount]
        balances
      end
    end
  end
end
