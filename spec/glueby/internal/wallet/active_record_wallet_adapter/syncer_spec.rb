# frozen_string_literal: true

RSpec.describe 'Glueby::Internal::Wallet::ActiveRecordWalletAdapter::Syncer' do
  describe "tx_sync", active_record: true do
    subject { syncer.tx_sync(tx) }
    let(:syncer) { Glueby::Internal::Wallet::ActiveRecordWalletAdapter::Syncer.new }

    let(:tx) do
      Tapyrus::Tx.new.tap do |tx|
        tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', 0))
        tx.outputs << Tapyrus::TxOut.new(value: 600, script_pubkey: Tapyrus::Script.parse_from_payload('76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac'.htb))
        tx.outputs << Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.parse_from_payload('21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac'.htb))
      end
    end
    let(:private_key) { '206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff' }

    before do
      key = Glueby::Internal::Wallet::AR::Key.create(
        private_key: private_key, 
        purpose: :change
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 0,
        script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        value: 1,
        status: :finalized,
        key: key
      )
    end

    it 'create and destroy Utxos' do
      subject

      # Used Utxo is deleted
      expect(Glueby::Internal::Wallet::AR::Utxo.find_by(txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', index: 0)).to be_nil

      # New Utxos
      expect(Glueby::Internal::Wallet::AR::Utxo.find_by(txid: tx.txid, index: 0)).not_to be_nil
      expect(Glueby::Internal::Wallet::AR::Utxo.find_by(txid: tx.txid, index: 1)).not_to be_nil
    end
  end
end