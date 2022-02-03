RSpec.describe 'Glueby::AR::SystemInformation', active_record: true do

  describe '#synced_block_number' do
    describe '#valid' do
      subject { Glueby::AR::SystemInformation.count }
      it { expect(subject).to be 1 }
    end

    describe '#invalid' do
      context 'info_key is unique' do 
        subject do
          Glueby::AR::SystemInformation.create(
            info_key: 'synced_block_number',
            info_value: '0'
          )
        end
        it { expect {subject}.to raise_error ActiveRecord::RecordNotUnique }
      end
    end
  end

  describe '.synced_block_height' do
    subject { Glueby::AR::SystemInformation.synced_block_height }

    it { expect(subject.info_value.to_i).to be 0 }
  end

  describe '.use_only_finalized_utxo?' do
    subject { Glueby::AR::SystemInformation.use_only_finalized_utxo? }

    context 'default value' do
      it { expect(subject).to be_truthy }
    end

    context 'if info_value is 0' do
      before do
        Glueby::AR::SystemInformation.create(
          info_key: 'use_only_finalized_utxo',
          info_value: '0'
        )
      end
      it { expect(subject).to be_falsy }
    end

    context 'if info_value is 1' do
      before do
        Glueby::AR::SystemInformation.create(
          info_key: 'use_only_finalized_utxo',
          info_value: '1'
        )
      end

      it { expect(subject).to be_truthy }
    end
  end

  describe '.int_value' do
    subject { Glueby::AR::SystemInformation.synced_block_height }

    it { expect(subject.int_value).to be 0 }
  end

  describe '.set_utxo_provider_pool_size' do
    let(:size) { 5 }
    subject { Glueby::AR::SystemInformation.set_utxo_provider_pool_size(5) }

    it { expect(subject.info_value.to_i).to eq size }
  end

end