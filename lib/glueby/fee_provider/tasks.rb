module Glueby
  class FeeProvider
    class Tasks
      attr_reader :fee_provider

      STATUS = {
        # FeeProvider is ready to pay fees.
        ready: 'Ready',
        # FeeProvider is ready to pay fees, but it doesn't have enough amount to fill the UTXO pool by UTXOs which is for paying fees.
        insufficient_amount: 'Insufficient Amount',
        # FeeProvider is not ready to pay fees. It has no UTXOs for paying fee and amounts.
        not_ready: 'Not Ready'
      }

      def initialize
        @fee_provider = Glueby::FeeProvider.new
      end

      # Create UTXOs for paying fee from TPC amount of the wallet FeeProvider has. Then show the status.
      #
      # About the UTXO Pool
      # FeeProvider have the UTXO pool. the pool is manged to keep some number of UTXOs that have fixed fee value. The
      # value is configurable by :fixed_fee. This method do the management to the pool.
      def manage_utxo_pool
        txb = Tapyrus::TxBuilder.new

        sum, utxos = collect_outputs
        return if utxos.empty?

        utxos.each { |utxo| txb.add_utxo(utxo) }
        address = wallet.receive_address

        shortage = [fee_provider.utxo_pool_size - current_utxo_pool_size, 0].max
        can_create = (sum - fee_provider.fixed_fee) / fee_provider.fixed_fee
        fee_outputs_count_to_be_created = [shortage, can_create].min

        return if fee_outputs_count_to_be_created == 0

        fee_outputs_count_to_be_created.times do
          txb.pay(address, fee_provider.fixed_fee)
        end

        tx = txb.change_address(address)
                .fee(fee_provider.fixed_fee)
                .build
        tx = wallet.sign_tx(tx)
        wallet.broadcast(tx)
      ensure
        status
      end

      # Show the status of the UTXO pool
      def status
        status = :ready

        if current_utxo_pool_size < fee_provider.utxo_pool_size
          if tpc_amount < value_to_fill_utxo_pool
            status = :insufficient_amount
            message = <<~MESSAGE
            1. Please replenishment TPC which is for paying fee to FeeProvider. 
               FeeProvider needs #{value_to_fill_utxo_pool} tapyrus at least for paying 20 transaction fees. 
               FeeProvider wallet's address is '#{wallet.receive_address}'
            2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'
            MESSAGE
          else
            message = "Please create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'\n"
          end
        end

        status = :not_ready if current_utxo_pool_size == 0

        puts <<~EOS
        Status: #{STATUS[status]}
        TPC amount: #{delimit(tpc_amount)}
        UTXO pool size: #{delimit(current_utxo_pool_size)}
        #{"\n" if message}#{message}
        Configuration:
          fixed_fee = #{delimit(fee_provider.fixed_fee)}
          utxo_pool_size = #{delimit(fee_provider.utxo_pool_size)}
        EOS
      end

      private

      def check_wallet_amount!
        if tpc_amount < fee_provider.fixed_fee
          raise InsufficientTPC, <<~MESSAGE
            FeeProvider has insufficient TPC to create fee outputs to fill the UTXO pool.
            1. Please replenishment TPC which is for paying fee to FeeProvider. FeeProvider needs #{fee_provider.utxo_pool_size * fee_provider.fixed_fee} tapyrus at least. FeeProvider wallet's address is '#{wallet.receive_address}'
            2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'
          MESSAGE
        end
      end

      def tpc_amount
        wallet.balance(false)
      end

      def collect_outputs
        wallet.list_unspent.inject([0, []]) do |sum, output|
          next sum if output[:color_id] || output[:amount] == fee_provider.fixed_fee

          new_sum = sum[0] + output[:amount]
          new_outputs = sum[1] << {
            txid: output[:txid],
            script_pubkey: output[:script_pubkey],
            value: output[:amount],
            index: output[:vout] ,
            finalized: output[:finalized]
          }
          return [new_sum, new_outputs] if new_sum >= value_to_fill_utxo_pool

          [new_sum, new_outputs]
        end
      end

      def current_utxo_pool_size
        wallet
          .list_unspent(false)
          .count { |o| !o[:color_id] && o[:amount] == fee_provider.fixed_fee }
      end

      def value_to_fill_utxo_pool
        fee_provider.fixed_fee * (fee_provider.utxo_pool_size + 1) #  +1 is for paying fee
      end

      def wallet
        fee_provider.wallet
      end

      def delimit(num)
        num.to_s.reverse.scan(/.{1,3}/).join('_').reverse
      end
    end
  end
end