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

        # Returns all the UTXOs that the wallet has.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @param [Boolean] only_finalized - The UTXOs includes only finalized UTXO value if it
        #                                   is true. Default is true.
        # @return [Array of UTXO]
        #
        # ## The UTXO structure
        #
        # - txid: [String] Transaction id
        # - vout: [Integer] Output index
        # - amount: [Integer] Amount of the UTXO as tapyrus unit
        # - finalized: [Boolean] Whether the UTXO is finalized
        def list_unspent(wallet_id, only_finalized = true)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
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
        # @return [String] txid
        def broadcast(wallet_id, tx)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns an address to receive coin.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [String] P2PKH address
        def receive_address(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end

        # Returns an address to change coin.
        #
        # @param [String] wallet_id - The wallet id that is offered by `create_wallet()` method.
        # @return [String] P2PKH address
        def change_address(wallet_id)
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
        # @return [Array<String>] array of P2PKH address
        def get_addresses(wallet_id)
          raise NotImplementedError, "You must implement #{self.class}##{__method__}"
        end
      end
    end
  end
end