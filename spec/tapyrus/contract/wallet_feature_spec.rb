RSpec.describe 'Tapyrus::Contract::WalletFeature' do
  class Wallet
    include Tapyrus::Contract::WalletFeature
  end

  let(:wallet) { Wallet.new }
  let(:key) { Tapyrus::Key.new(priv_key: '206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff') }

  before { allow(Tapyrus::Key).to receive(:generate).and_return(key) }

  describe '#to_p2pkh' do
    subject { wallet.to_p2pkh.bth }

    it { is_expected.to eq '76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac' }
  end

  describe '#address' do
    subject { wallet.address }

    it { is_expected.to eq '191arn68nSLRiNJXD8srnmw4bRykBkVv6o' }
  end
end
