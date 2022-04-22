RSpec.describe Glueby::Contract::Timestamp::Syncer, active_record: true do
  describe '#block_sync' do
    before do
      Glueby::Contract::AR::Timestamp.create(
        txid: nil,
        status: :init,
        wallet_id: "5f924e7e5daf624616f96b2f659938d7" ,
        content: "\xFF\xFF\xFF",
        prefix: "app")

      Glueby::Contract::AR::Timestamp.create(
        txid: 'd90759e30adf2eb9537bbd3ab1205ed5054cf873539c18947b36be1d6bb56f05',
        status: :confirmed,
        wallet_id: "5f924e7e5daf624616f96b2f659938d7" ,
        content: "\xFF\xFF\xFF",
        prefix: "app")
    end

    let!(:unconfirmed) do
      r = Glueby::Contract::AR::Timestamp.create(
        wallet_id: "5f924e7e5daf624616f96b2f659938d7" ,
        content: "\xFF\xFF\xFF",
        prefix: "app")
      r.update(status: :unconfirmed, txid: '79a5a199e6f3a59345c1132235c142464d0ba906266c223f245e623e8e451909')
      r
    end

    # The block that has a transaction that is correspond to unconfirmed record.
    let(:block) do
      Tapyrus::Block.parse_from_payload('010000004e6a0661968b3c6e56df7f91b11b3e1b4dbb938856c659e982a67271998be2508c09e59c3230fcac48fb5ab1d673146a301e5e28759899be5f7d343dbed4dd2c526dc08fee1b48f875037e02ad5b2f5b33ebf11aac911111c6ee790607569745b083d960004049b663bed8f81b687d053dbaaf7983b6e6c1b95f3c40eb357cae0c5417bddfa52139a19e7ac129c3b525c17aec4ab5591675eb79aa5973c600ea57cd2a5ff08802010000000100000000000000000000000000000000000000000000000000000000000000000200000003520101ffffffff011019062a010000001976a914200afd9849e5fcd0d9b28cc2e34c886b1abf443e88ac000000000100000001e695a4786255802559bb8bb7dad9afe286a49083f357c09bef04cc294bdd498a0000000064412f37b952f8148b12cd4ec7ad503d0b691ce30d425407bada38fac88f11743985420537c6d4e87574725416b1cb0ed8a0bf7efd2e9bfba19e7207ba2ae4053d5c0121021b9cc5255a5241a622a416e88d51b3d4d6cfa6c7c79eb245edba5308c162736cffffffff020000000000000000246a22a995ae7e6a42304dc6e4176210b83c43024f99a0bce9a870c3b6d2c95fc8ebfb74c0f0ca052a010000001976a9142ba6bd05444e97d1702a0fb9a745d77e39b3bace88ac00000000'.htb)
    end

    subject { described_class.new.block_sync(block) }

    it 'update block_time and block_height' do
      subject
      expect(unconfirmed.reload.block_time).to eq 1624867760
      expect(unconfirmed.reload.block_height).to eq 2
    end

    it 'changes unconfirmed timestamp record' do
      expect { subject }
        .to change { Glueby::Contract::AR::Timestamp.find(unconfirmed.id).status }
              .from("unconfirmed")
              .to("confirmed")
    end
  end
end