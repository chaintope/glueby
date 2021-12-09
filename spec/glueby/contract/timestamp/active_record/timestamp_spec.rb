
RSpec.describe 'Glueby::Contract::AR::Timestamp', active_record: true do
  describe '#latest' do
    subject { timestamp.latest }

    let(:timestamp) do
      Glueby::Contract::AR::Timestamp.create(wallet_id: '00000000000000000000000000000000', content: "\xFF\xFF\xFF", prefix: 'app', timestamp_type: timestamp_type)
    end

    context 'timestamp type is simple' do
      let(:timestamp_type) { :simple }

      it { is_expected.to be_falsy }
    end

    context 'timestamp type is trackable' do
      let(:timestamp_type) { :trackable }

      it { is_expected.to be_truthy }
    end
  end
end
