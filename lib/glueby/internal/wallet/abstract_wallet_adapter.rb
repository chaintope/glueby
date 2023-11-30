module Glueby
  module Internal
    class Wallet
      # This is an abstract class for wallet adapters. If you want to use a wallet
      # component with Glueby modules, you can use it by adding subclass of this abstract
      # class for the wallet component.
      class AbstractWalletAdapter
        # Creates a new wallet inside the wallet component and returns `wallet_id`. The created
        # wallet is loaded from at first.
        # @params [String] wallet_id - Option. The wallet id that if for the wallet to be created. If this is nil, wallet adapter generates it.
        # @return [String] wallet_id
        # @raise [Glueby::Internal::Wallet::Errors::WalletAlreadyCreated] when the specified wallet has been already created.
        def create_wallet(wallet_id = nil)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Delete the wallet inside the wallet component.
        # This method expect that the wallet will be removed completely
        # in the wallet and it cannot restore. It is assumed that the main use-case of
        # this method is for testing.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [Boolean] The boolean value whether the deletion was success.
        def delete_wallet(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Load the wallet inside the wallet component.
        # This method makes the wallet to possible to use on other methods like `balance`,
        # `list_unspent`, etc. All the methods that gets `wallet_id` as a argument needs to
        # load the wallet before use it.
        # If the wallet component doesn't need such as load operation to prepare to use the
        # wallet, `load_wallet` can be empty method.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @raise [Glueby::Internal::Wallet::Errors::WalletAlreadyLoaded] when the specified wallet has been already loaded.
        # @raise [Glueby::Internal::Wallet::Errors::WalletNotFound] when the specified wallet is not found.
        def load_wallet(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Unload the wallet inside the wallet component.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [Boolean] The boolean value whether the unloading was success.
        def unload_wallet(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns list of loaded wallet_id.
        #
        # @return [Array of String] - Array of wallet_id
        def wallets
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns amount of tapyrus that the wallet has.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Boolean] only_finalized - The balance includes only finalized UTXO value if it
        #                                   is true. Default is true.
        # @return [Integer] The balance of the wallet. The unit is 'tapyrus'.
        #                   1 TPC equals to 10^8 'tapyrus'.
        def balance(wallet_id, only_finalized = true)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns all tokens with specified color_id
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Color::ColorIdentifier] color_id The color identifier associated with UTXO.
        #                                                     It will return only UTXOs with specified color_id. If color_id is nil, it will return all UTXOs.
        #                                                     If Tapyrus::Color::ColorIdentifier.default is specified, it will return uncolored UTXOs(i.e. TPC)
        # @param [Boolean] only_finalized - includes only finalized UTXO value if it
        #                                   is true. Default is true.
        # @param [Integer] page - The page parameter is responsible for specifying the current page being viewed within the paginated results. default is 1.
        # @param [Integer] per - The per parameter is used to determine the number of items to display per page. default is 25.
        # @return [Array<Utxo>] The array of the utxos with specified color_id
        def list_unspent_with_count(wallet_id, color_id = nil, only_finalized = true, label = nil, page = 1, per = 25)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns the UTXOs that the wallet has.
        # If label is specified, return UTXOs filtered with label
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Color::ColorIdentifier] color_id - The color identifier. 
        #                                                     It will return only UTXOs with specified color_id. If color_id is nil, it will return all UTXOs.
        #                                                     If Tapyrus::Color::ColorIdentifier.default is specified, it will return uncolored UTXOs(i.e. TPC)
        # @param [Boolean] only_finalized - The UTXOs includes only finalized UTXO value if it
        #                                   is true. Default is true.
        # @param [String] label - Label for filtering UTXOs
        #                       - If label is nil or :unlabeled, only unlabeled UTXOs will be returned.
        #                       - If label=:all, it will return all utxos
        # @return [Array of UTXO]
        #
        # ## The UTXO structure
        #
        # - txid: [String] Transaction id
        # - vout: [Integer] Output index
        # - amount: [Integer] Amount of the UTXO as tapyrus unit
        # - finalized: [Boolean] Whether the UTXO is finalized
        # - color_id: [String] Color id of the UTXO. If it is TPC UTXO, color_id is nil.
        # - script_pubkey: [String] Script pubkey of the UTXO
        def list_unspent(wallet_id, color_id = nil, only_finalized = true, label = nil)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Attempt to lock a specified utxo and update lock_at field
        #
        # @param wallet_id [String] The wallet id that is offered by `create_wallet()` method.
        # @param utxo [Hash] The utxo hash object
        def lock_unspent(wallet_id, utxo)
          true
        end

        # Sign to the transaction with a key in the wallet.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Tx] tx - The transaction will be signed.
        # @param [Array] prevtxs - array of hash that represents unbroadcasted transaction outputs used by signing tx.
        #                Each hash has `txid`, `vout`, `scriptPubKey`, `amount` fields.
        # @param [Integer] sighashtype - The sighash flag for each signature that would be produced here.
        # @return [Tapyrus::Tx]
        # @raise [Glueby::Internal::Wallet::Errors::InvalidSighashType] when the specified sighashtype is invalid
        def sign_tx(wallet_id, tx, prevtxs = [], sighashtype: Tapyrus::SIGHASH_TYPE[:all])
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Broadcast the transaction to the Tapyrus Network.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Tx] tx - The transaction to be broadcasterd.
        # @yield Option. If a block given, the block is called before actual broadcasting.
        #   @yieldparam [Tapyrus::Tx] tx - The tx that is going to be broadcasted as is.
        # @return [String] txid
        def broadcast(wallet_id, tx, &block)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns an address to receive coin.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [String] label The label associated with this address.
        # @return [String] P2PKH address
        def receive_address(wallet_id, label = nil)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns an address to change coin.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [String] P2PKH address
        def change_address(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns information for the addresses
        #
        # @param [String, Array<String>] addresses - The p2pkh address to get information about
        # @return [Array<Hash>] The array of hash instance which has keys wallet_id, label and purpose.
        #                       Returns blank array if the key correspond with the address is not exist.
        def get_addresses_info(addresses)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns a new public key.
        #
        # This method is expected to returns a new public key. The key would generate internally. This key is provided
        # for contracts that need public key such as multi sig transaction.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [Tapyrus::Key]
        def create_pubkey(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns an array of addresses
        #
        # This method is expected to return the list of addresses that wallet has.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [String] label The label to filter the addresses.
        # @return [Array<String>] array of P2PKH address
        def get_addresses(wallet_id, label = nil)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Create and returns pay to contract address
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [String] contents - The data to be used for generating pay-to-contract address
        # @return [String] pay to contract P2PKH address
        def create_pay_to_contract_address(wallet_id, contents)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Create pay to contract key
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Key] payment_base - The public key used to generate pay to contract public key
        # @param [String] contents - The data to be used for generating pay-to-contract address
        # @return [Tapyrus::Key] Key for pay to contract 
        def pay_to_contract_key(wallet_id, payment_base, contents)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Sign to the pay to contract input
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Tapyrus::Tx] tx - The tx that has pay to contract input in the inputs list
        # @param [Hash] utxo - The utxo that indicates pay to contract output to be signed
        # @option utxo [String] txid - Transaction id
        # @option utxo [Integer] vout - Output index
        # @option utxo [Integer] amount - The amount the output has
        # @option utxo [String] script_pubkey - The script_pubkey hex string
        # @param [String] payment_base - The public key that is used to generate pay to contract public key
        # @param [String] contents - The data to be used for generating pay-to-contract address
        # @param [Integer] sighashtype - The sighash flag for each signature that would be produced here.
        # @return [Tapyrus::Tx]
        # @raise [Glueby::Internal::Wallet::Errors::InvalidSighashType] when the specified sighashtype is invalid
        # @raise [Glueby::Internal::Wallet::Errors::InvalidSigner] when the wallet don't have any private key of the specified payment_base
        def sign_to_pay_to_contract_address(wallet_id, tx, utxo, payment_base, contents, sighashtype: Tapyrus::SIGHASH_TYPE[:all])
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Return if wallet has the address
        # @param wallet_id [String] The wallet id that is offered by `create_wallet()` method.
        # @param address [String] address
        # @return [Boolean] true if the wallet has an address, false otherwise
        def has_address?(wallet_id, address)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end
      end
    end
  end
end