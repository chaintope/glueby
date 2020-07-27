RSpec.describe 'Glueby::Internal::RPC' do
  describe 'perform_as' do
    subject { Glueby::Internal::RPC.perform_as(wallet_name) }
    let(:wallet_name) { 'wallet' }

    before do
      Glueby::Internal::RPC.configure(config)
    end

    after do
      Glueby::Internal::RPC.instance_variable_set(:@rpc, nil)
    end

    let(:config) { { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' } }

    it 'should switch wallet only while processing the block' do
      rt = Glueby::Internal::RPC.perform_as(wallet_name) do |client|
        # It should update config in the block
        expect(client.config[:wallet]).to eq wallet_name

        'Return value of the block'
      end

      # It should revert the config.
      expect(Glueby::Internal::RPC.client.config[:wallet]).to be_nil

      # It should returns the value the block returns.
      expect(rt).to eq 'Return value of the block'
    end

    context 'raise an error on the RPC calling' do
      it 'should revert wallet config when the block raises an error' do
        begin
          Glueby::Internal::RPC.perform_as(wallet_name) do
            raise RuntimeError, 'an error'
          end
        rescue RuntimeError
          # Ignore the error.
        end

        # It should revert the config.
        expect(Glueby::Internal::RPC.client.config[:wallet]).to be_nil
      end
    end
  end
end
