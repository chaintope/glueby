RSpec.describe 'Glueby::Contract::AR::ReissuableToken', active_record: true do

  describe '.saved?' do

    before do
      Glueby::Contract::AR::ReissuableToken.create!(color_id: color_id.to_hex, script_pubkey: script_pubkey.to_hex)
    end

    let(:script_pubkey) { Tapyrus::Script.parse_from_payload('76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac'.htb) }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.reissuable(script_pubkey) }

    it 'return true if exists' do
      expect(Glueby::Contract::AR::ReissuableToken.saved?(color_id.to_hex)).to eq true
    end

    it 'return false if otherwise' do
      expect(Glueby::Contract::AR::ReissuableToken.saved?("c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016")).to eq false
    end
  end
end
