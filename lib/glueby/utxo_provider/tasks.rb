module Glueby
  class UtxoProvider
    class Tasks
      include Glueby::Contract::TxBuilder

      attr_reader :utxo_provider

      STATUS = {
        # UtxoProvider is ready to pay tpcs.
        ready: 'Ready',
        # UtxoProvider is ready to pay tpcs, but it doesn't have enough amount to fill the UTXO pool by UTXOs which is for paying tpcs.
        insufficient_amount: 'Insufficient Amount',
        # UtxoProvider is not ready to pay tpcs. It has no UTXOs for paying amounts.
        not_ready: 'Not Ready'
      }

      def initialize
        @utxo_provider = Glueby::UtxoProvider.new
      end

      # Create UTXOs for paying tpc
      #
      # UtxoProvider have the UTXO pool. the pool is manged to keep some number of UTXOs that have fixed value. The
      # value is configurable by :default_value. This method do the management to the pool.
      def manage_utxo_pool
        txb = Tapyrus::TxBuilder.new

        sum, utxos = collect_outputs
        return if utxos.empty?

        utxos.each { |utxo| txb.add_utxo(utxo) }
        address = wallet.receive_address

        shortage = [utxo_provider.utxo_pool_size - current_utxo_pool_size, 0].max
        return if shortage == 0

        added_outputs = 0
        shortage.times do
          fee = utxo_provider.fee_estimator.fee(dummy_tx(txb.build))
          break if (sum - fee) < utxo_provider.default_value
          txb.pay(address, utxo_provider.default_value)
          sum -= utxo_provider.default_value
          added_outputs += 1
        end

        return if added_outputs == 0

        fee = utxo_provider.fee_estimator.fee(dummy_tx(txb.build))
        tx = txb.change_address(address)
                .fee(fee)
                .build
        tx = wallet.sign_tx(tx)
        wallet.broadcast(tx)
      ensure
        status
      end

      # Show the status of the UTXO pool
      def status
        status = :ready

        if current_utxo_pool_size < utxo_provider.utxo_pool_size
          if tpc_amount < value_to_fill_utxo_pool
            status = :insufficient_amount
            message = <<~MESSAGE
            1. Please replenishment TPC which is for paying tpc to UtxoProvider. 
              UtxoProvider needs #{value_to_fill_utxo_pool} tapyrus in UTXO pool. 
              UtxoProvider wallet's address is '#{wallet.receive_address}'
            2. Then create UTXOs for paying in UTXO pool with 'rake glueby:utxo_provider:manage_utxo_pool'
            MESSAGE
          else
            message = "Please create UTXOs for paying in UTXO pool with 'rake glueby:utxo_provider:manage_utxo_pool'\n"
          end
        end

        status = :not_ready if current_utxo_pool_size == 0

        puts <<~EOS
        Status: #{STATUS[status]}
        TPC amount: #{delimit(tpc_amount)}
        UTXO pool size: #{delimit(current_utxo_pool_size)}
        #{"\n" if message}#{message}
        Configuration:
          default_value = #{delimit(utxo_provider.default_value)}
          utxo_pool_size = #{delimit(utxo_provider.utxo_pool_size)}
        EOS
      end

      # Show the address of Utxo Provider 
      def print_address
        puts wallet.receive_address
      end

      private

      def tpc_amount
        wallet.balance(false)
      end

      def collect_outputs
        wallet.list_unspent.inject([0, []]) do |sum, output|
          next sum if output[:color_id] || output[:amount] == utxo_provider.default_value

          new_sum = sum[0] + output[:amount]
          new_outputs = sum[1] << {
            txid: output[:txid],
            script_pubkey: output[:script_pubkey],
            value: output[:amount],
            index: output[:vout] ,
            finalized: output[:finalized]
          }
          [new_sum, new_outputs]
        end
      end

      def current_utxo_pool_size
        wallet
          .list_unspent(false)
          .count { |o| !o[:color_id] && o[:amount] == utxo_provider.default_value }
      end

      def value_to_fill_utxo_pool
        utxo_provider.default_value * utxo_provider.utxo_pool_size
      end

      def wallet
        utxo_provider.wallet
      end

      def delimit(num)
        num.to_s.reverse.scan(/.{1,3}/).join('_').reverse
      end
    end
  end
end