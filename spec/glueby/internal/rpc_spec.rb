RSpec.describe 'Glueby::Internal::RPC' do
  describe 'switch_wallet' do
    subject { Glueby::Internal::RPC.switch_wallet(wallet_name) }
    let(:wallet_name) { 'wallet' }

    before do
      Glueby::Internal::RPC.configure(config)
    end

    let(:config) { {schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'} }

    it 'should change the config[:wallet] value inner RPC client' do
      expect(subject).to eq wallet_name
      expect(Glueby::Internal::RPC.client.config[:wallet]).to eq wallet_name
    end

    context 'It is received a block argument' do
      it 'should switch wallet only while processing the block' do
        rt = Glueby::Internal::RPC.switch_wallet(wallet_name) do |client|
          # It should update config in the block
          expect(client.config[:wallet]).to eq wallet_name

          'Return value of the block'
        end

        # It should revert the config.
        expect(Glueby::Internal::RPC.client.config[:wallet]).to be_nil

        # It should returns the value the block returns.
        expect(rt).to eq 'Return value of the block'
      end
    end
  end
end
