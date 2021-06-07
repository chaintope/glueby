# frozen_string_literal: true

RSpec.describe 'Glueby::Internal::Wallet::AR::Wallet', active_record: true do
  let(:wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') }

  describe '#sign' do
    subject { wallet.sign(tx, prevtxs, sighashtype: sighashtype) }

    let(:sighashtype) { Tapyrus::SIGHASH_TYPE[:all] }
    let(:key1) { wallet.keys.create(purpose: :receive) }
    let(:key2) { wallet.keys.create(purpose: :receive) }
    let(:tx) do
      tx = Tapyrus::Tx.new
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('00' * 32, 0))
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('11' * 32, 0))
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('22' * 32, 0))
      tx.outputs << Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.new)
      tx
    end
    let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c185856a84c483fb108b1cdf79ff53aa7d54d1a137a5178684bd89ca31f906b2bd'.htb) }
    let(:prevtxs) { [] }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        value: 1,
        script_pubkey: key1.to_p2pkh.to_hex,
        status: :init,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '1111111111111111111111111111111111111111111111111111111111111111',
        index: 0,
        value: 1,
        script_pubkey: key2.to_p2pkh.to_hex,
        status: :init,
        key: key2
      )
      colored_script = key1.to_p2pkh.add_color(color_id)
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '2222222222222222222222222222222222222222222222222222222222222222',
        index: 0,
        script_pubkey: colored_script.to_hex,
        value: 1,
        status: :finalized,
        key: key1
      )
    end

    it do
      subject
      expect(tx.verify_input_sig(0, key1.to_p2pkh)).to be_truthy
      expect(tx.verify_input_sig(1, key2.to_p2pkh)).to be_truthy
      expect(tx.verify_input_sig(2, key1.to_p2pkh.add_color(color_id))).to be_truthy
    end

    context 'with previout txs' do
      let(:prevtxs) do
        [
          {
            txid: '33' * 32,
            vout: 0,
            scriptPubKey: key1.to_p2pkh.to_hex,
            amount: 1
          }
        ]
      end

      before { tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('33' * 32, 0)) }

      it do
        subject
        expect(tx.verify_input_sig(3, key1.to_p2pkh)).to be_truthy
      end
    end

    context 'utxo is not stored and is not contained in prevtxs' do
      let(:prevtxs) do
        [
          {
            txid: '33' * 32,
            vout: 0,
            scriptPubKey: key1.to_p2pkh.to_hex,
            amount: 1
          }
        ]
      end

      before { tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('33' * 32, 1)) }

      it 'does not sign to unknown input' do
        subject
        expect(tx.inputs[3].script_sig).to eq Tapyrus::Script.new
      end
    end

    context 'sighash type is ALL | ANYONECANPAY' do
      let(:sighashtype) { Tapyrus::SIGHASH_TYPE[:all] | Tapyrus::SIGHASH_TYPE[:anyonecanpay] }

      it 'generates valid signatures' do
        subject
        expect(tx.verify_input_sig(0, key1.to_p2pkh)).to be_truthy
        expect(tx.verify_input_sig(1, key2.to_p2pkh)).to be_truthy
        expect(tx.verify_input_sig(2, key1.to_p2pkh.add_color(color_id))).to be_truthy
      end

      it 'sets sighashtype 0x81 behind signature' do
        subject
        signature = tx.inputs[0].script_sig.chunks[0]
        expect(signature[-1].unpack('C')[0]).to eq sighashtype
      end
    end

    context 'invalid sighashtype 1' do
      let(:sighashtype) { 0x90 }

      it do
        expect { subject }.to raise_error(error=Glueby::Internal::Wallet::Errors::InvalidSighashType, message='Invalid sighash type \'144\'')
      end
    end

    context 'invalid sighashtype 2' do
      let(:sighashtype) { 0x4 }

      it do
        expect { subject }.to raise_error(error=Glueby::Internal::Wallet::Errors::InvalidSighashType, message='Invalid sighash type \'4\'')
      end
    end
  end

  describe '#valid' do
    subject { wallet }
    
    context 'wallet_id is unique' do
      it { is_expected.to be_valid }
    end

    context 'wallet_id is not unique' do
      before { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') }

      it { is_expected.to be_invalid }
    end

    context 'wallet_id is lower case' do
      before { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'ffffffffffffffffffffffffffffffff') }

      it { is_expected.to be_invalid }
    end
  end
end
