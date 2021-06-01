# frozen_string_literal: true

RSpec.describe 'Glueby::FeeProvider' do
  let(:wallet_adapter) { double(:wallet_adapter) }

  before do
    Glueby::Internal::Wallet.wallet_adapter = wallet_adapter
    allow(wallet_adapter).to receive(:load_wallet)
  end

  after { Glueby::Internal::Wallet.wallet_adapter = nil }

  describe '#provide' do
    subject { Glueby::FeeProvider.provide(tx) }

    before do
      allow(wallet_adapter).to receive(:list_unspent).and_return([dummy_utxos, utxo_for_paying_fee].flatten)
    end

    let(:utxo_for_paying_fee) do
      {
        txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
        script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
        vout: 0,
        amount: 1000,
        finalized: true
      }
    end

    let(:dummy_utxos) do
      [{
        txid: '3c1619e82b2d796caddea61dd2d740792323bc0082a69da77227c773cd9d21e8',
        script_pubkey: '21c156f3482615d7ff1908de037f68dd5c0c4d80479799c3ad1926cdcdf2ae9f7e60bc76a9147b93e3b9fd211d1408ea855f22cb17124e51408988ac',
        vout: 0,
        amount: 1000,
        color_id: 'c156f3482615d7ff1908de037f68dd5c0c4d80479799c3ad1926cdcdf2ae9f7e60',
        finalized: true
      }, {
        txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
        script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
        vout: 0,
        amount: 2000,
        finalized: true
      }]
    end
    # The tx that would be added an input for paying fee by FeeProvider
    # Initially it has one input and two outputs which is for transfer and change.
    let(:tx) { Tapyrus::Tx.parse_from_payload("01000000018939a2974964f144941ed79c60a0046ee9f842f3b60453ea7d4533601c7ca030000000006a473044022004e5c255e7f397d3ea67e104b00bebfc31cff8d8f57b4c4972473936dda35d8e0220562676a1d1dfd85c89d596e7e96eaa178f8ef4b30c109c561612435137a8860481210280b5f253e612294a2c15a912bbb39b1d5ea48163c14bff56fd1a7079fed23258ffffffff02e8030000000000001976a91402b5fb1195e4c7b069ac33751d03d73a216babe588ac28230000000000001976a9148981ef639f525dc87b0c92ea9fb9af5148cf229688ac00000000".htb) }
    let(:added_fee_input_tx) { Tapyrus::Tx.parse_from_payload("01000000028939a2974964f144941ed79c60a0046ee9f842f3b60453ea7d4533601c7ca030000000006a473044022004e5c255e7f397d3ea67e104b00bebfc31cff8d8f57b4c4972473936dda35d8e0220562676a1d1dfd85c89d596e7e96eaa178f8ef4b30c109c561612435137a8860481210280b5f253e612294a2c15a912bbb39b1d5ea48163c14bff56fd1a7079fed23258ffffffffc57c5e3dfb5a147710a080cb73628b5df12e7d5172abb8824297f41f04793d5c0000000000ffffffff02e8030000000000001976a91402b5fb1195e4c7b069ac33751d03d73a216babe588ac28230000000000001976a9148981ef639f525dc87b0c92ea9fb9af5148cf229688ac00000000".htb) }

    it 'calls wallet apdater #sign_tx with a tx that is added a fee input' do
      expect(wallet_adapter).to receive(:sign_tx).with(
        Glueby::FeeProvider::WALLET_ID,
        added_fee_input_tx,
        [],
        sighashtype: Tapyrus::SIGHASH_TYPE[:all]
      )
      subject
    end

    context 'There are no suitable UTXO for paying fee' do
      let(:utxo_for_paying_fee) { [] }
      it do
        expect { subject }.to raise_error(Glueby::FeeProvider::NoUtxosInUtxoPool, 'No UTXOs in Fee Provider UTXO pool. UTXOs should be created with "glueby:fee_provider:manage_utxo_pool" rake task')
      end
    end

    context 'Signatures in tx don\'t have ANYONECNAPAY flag' do
      let(:tx) { Tapyrus::Tx.parse_from_payload("01000000018939a2974964f144941ed79c60a0046ee9f842f3b60453ea7d4533601c7ca030000000006a473044022004e5c255e7f397d3ea67e104b00bebfc31cff8d8f57b4c4972473936dda35d8e0220562676a1d1dfd85c89d596e7e96eaa178f8ef4b30c109c561612435137a8860401210280b5f253e612294a2c15a912bbb39b1d5ea48163c14bff56fd1a7079fed23258ffffffff02e8030000000000001976a91402b5fb1195e4c7b069ac33751d03d73a216babe588ac28230000000000001976a9148981ef639f525dc87b0c92ea9fb9af5148cf229688ac00000000".htb) }

      it 'raise ArgumentError' do
        expect { subject }.to raise_error(ArgumentError, 'All the signatures that the tx inputs has should have ANYONECANPAY flag.')
      end
    end
  end
end