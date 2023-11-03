# frozen_string_literal: true

RSpec.describe 'Glueby::Internal::Wallet::AbstractWalletAdapter'do
  let(:adapter) { Glueby::Internal::Wallet::AbstractWalletAdapter.new }

  describe '#create_wallet' do
    it 'does not implemented' do
      expect { adapter.create_wallet }.to raise_error(NotImplementedError)
    end
  end

  describe '#delete_wallet' do
    it 'does not implemented' do
      expect { adapter.delete_wallet("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#load_wallet' do
    it 'does not implemented' do
      expect { adapter.load_wallet("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#unload_wallet' do
    it 'does not implemented' do
      expect { adapter.unload_wallet("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#wallets' do
    it 'does not implemented' do
      expect { adapter.wallets }.to raise_error(NotImplementedError)
    end
  end

  describe '#balance' do
    it 'does not implemented' do
      expect { adapter.balance("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#tokens' do
    it 'does not implemented' do
      expect { adapter.tokens("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#list_unspent' do
    it 'does not implemented' do
      expect { adapter.list_unspent("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#lock_unspent' do
    it 'return true' do
      expect(adapter.lock_unspent("wallet_id", {})).to eq true
    end
  end

  describe '#sign_tx' do
    it 'does not implemented' do
      expect { adapter.sign_tx("wallet_id", Tapyrus::Tx.new) }.to raise_error(NotImplementedError)
    end
  end

  describe '#broadcast' do
    it 'does not implemented' do
      expect { adapter.broadcast("wallet_id", Tapyrus::Tx.new) }.to raise_error(NotImplementedError)
    end
  end

  describe '#receive_address' do
    it 'does not implemented' do
      expect { adapter.receive_address("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#change_address' do
    it 'does not implemented' do
      expect { adapter.change_address("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_addresses_info' do
    it 'does not implemented' do
      expect { adapter.get_addresses_info([]) }.to raise_error(NotImplementedError)
    end
  end

  describe '#create_pubkey' do
    it 'does not implemented' do
      expect { adapter.create_pubkey("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#get_addresses' do
    it 'does not implemented' do
      expect { adapter.get_addresses("wallet_id") }.to raise_error(NotImplementedError)
    end
  end

  describe '#create_pay_to_contract_address' do
    it 'does not implemented' do
      expect { adapter.create_pay_to_contract_address("wallet_id", "contents") }.to raise_error(NotImplementedError)
    end
  end

  describe '#pay_to_contract_key' do
    it 'does not implemented' do
      expect { adapter.pay_to_contract_key("wallet_id", Tapyrus::Key.generate, "contents") }.to raise_error(NotImplementedError)
    end
  end

  describe '#sign_to_pay_to_contract_address' do
    it 'does not implemented' do
      expect { adapter.sign_to_pay_to_contract_address("wallet_id", Tapyrus::Tx.new, {}, Tapyrus::Key.generate, "contents") }.to raise_error(NotImplementedError)
    end
  end

  describe '#has_address?' do
    it 'does not implemented' do
      expect { adapter.has_address?("wallet_id", "address") }.to raise_error(NotImplementedError)
    end
  end
end
