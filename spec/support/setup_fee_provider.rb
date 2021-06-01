RSpec.shared_context 'setup fee provider' do
  before do
    # create UTXOs in the UTXO pool
    fee_provider = Glueby::FeeProvider.new
    wallet = fee_provider.wallet
    process_block(to_address: wallet.receive_address)

    txb = Tapyrus::TxBuilder.new
    utxos = wallet.list_unspent.map { |i| i[:value] = i[:amount]; i[:index] = i[:vout]; i }
    txb.add_utxo(utxos.first)
    address = wallet.receive_address
    fee_provider.utxo_pool_size.times do
      txb.pay(address, fee_provider.fixed_fee)
    end
    tx = txb.change_address(address)
            .fee(fee_provider.fixed_fee)
            .build
    tx = wallet.sign_tx(tx)
    wallet.broadcast(tx)

    Glueby.configuration.fee_provider_bears!
  end

  after do
    Glueby.configuration.disable_fee_provider_bears!
  end
end