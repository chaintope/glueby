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

  describe '.from_wif' do
    subject(:wallet) { Wallet.from_wif('L2hmApEYQBQo81RLJc5MMwo6ZZywnfVzuQj6uCfxFLaV2Yo2pVyq') }

    it { expect(wallet.key.pubkey).to eq '03b8ad9e3271a20d5eb2b622e455fcffa5c9c90e38b192772b2e1b58f6b442e78d' }
  end
end
