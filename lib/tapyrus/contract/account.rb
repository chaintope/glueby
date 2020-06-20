module Tapyrus
  module Contract
    class Account

      attr_reader :purpose
      attr_reader :ar

      class << self
        attr_reader :master_key

        # @param [String] seed - hex string
        # @param [String] mnemonic - The mnemonic string, which the words separated by a white space
        # @return [Tapyrus::Wallet::MasterKey]
        def set_master_key(seed: nil, mnemonic: nil)
          raise 'Specify seed or mnemonic' unless seed.nil? || mnemonic.nil?

          @master_key = if !seed.nil?
                          Tapyrus::Wallet::MasterKey.new(seed)
                        elsif !mnemonic.nil?
                          Tapyrus::Wallet::MasterKey.recover_from_words(mnemonic.split(' '))
                        else
                          raise 'Specify seed or mnemonic'
                        end
        end

        # Crate an Account instance and a record on the database
        # @param [Integer] purpose The purpose which is BIP-44 2nd level. This is always 44.
        # @param [String] name Account name
        # @return [Tapyrus::Contract::Account]
        def create!(
          purpose: Tapyrus::Wallet::Account::PURPOSE_TYPE[:legacy],
          name: ''
        )
          ar = Tapyrus::Contract::AR::Account.create!(name: name)
          new(ar, purpose)
        end

        # Load an existing account on the database
        # @param [Integer] account_index - The BIP-44 account index
        # @return [Tapyrus::Contract::Account]
        def load(account_index)
          ar = Tapyrus::Contract::AR::Account.find(account_index)
          new(ar)
        rescue ActiveRecord::RecordNotFound
          raise "Can not load the account. account_index = #{account_index}"
        end
      end

      # @param [Tapyrus::Contract::AR::Account] ar
      # @param [Integer] purpose - The purpose of BIP-44 2nd depth
      def initialize(ar, purpose = Tapyrus::Wallet::Account::PURPOSE_TYPE[:legacy])
        @ar = ar
        @purpose = purpose
      end

      # Create a key for receiving from external
      # @return [Tapyrus::ExtKey]
      def create_receive
        last = ar.addresses.receive.reorder('address_index DESC').first
        address_index = last.nil? ? 0 : last.address_index + 1

        new_key = key.derive(0).derive(address_index)
        ar.addresses.receive.create!(address_index: address_index, pubkey: new_key.pub)
        new_key
      end

      # Create a key for change
      # @return [Tapyrus::ExtKey]
      def create_change
        last = ar.addresses.change.reorder('address_index DESC').first
        address_index = last.nil? ? 0 : last.address_index + 1

        new_key = key.derive(1).derive(address_index)
        ar.addresses.change.create!(address_index: address_index, pubkey: new_key.pub)
        new_key
      end

      # Get the list of derived keys for receive key.
      # @return [Array[Tapyrus::ExtPubkey]]
      def derived_receive_keys
        receive_key = key.derive(0)
        ar.addresses.receive.map { |addr| receive_key.derive(addr.address_index).ext_pubkey }
      end

      # Get the list of derived keys for change key.
      # @return [Array[Tapyrus::ExtPubkey]]
      def derived_change_keys
        change_key = key.derive(1)
        ar.addresses.change.map { |addr| change_key.derive(addr.address_index).ext_pubkey }
      end

      # Get a name of the account
      # @return [string]
      def name
        @ar.name
      end

      # Get a BIP-44 path of the account
      # @return [string]
      def path
        "m/#{purpose}'/#{Tapyrus.chain_params.bip44_coin_type}'/#{index}'"
      end

      # Get a BIP-44 account index of the account
      # @return [integer]
      def index
        ar.id
      end

      # Get a ext key of the account
      # @return [Tapyrus::ExtKey]
      def key
        @key ||= Tapyrus::Contract::Account.master_key.derive(path)
      end
    end
  end
end