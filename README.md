# Glueby [![Ruby](https://github.com/chaintope/glueby/actions/workflows/ruby.yml/badge.svg)](https://github.com/chaintope/glueby/actions/workflows/ruby.yml) [![Gem Version](https://badge.fury.io/rb/glueby.svg)](https://badge.fury.io/rb/glueby) [![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

Glueby is a smart contract library on the [Tapyrus blockchain](https://github.com/chaintope/tapyrus-core). This is 
designed as you can use without any deep blockchain understanding.

## Features

Glueby has below features.

1. Wallet
   You can manage wallets for application users. This wallet feature is a foundation of Contracts below to specify tx
   sender and so on.  
   You can choose two sorts of wallet implementation :activerecord and :core. :activerecord is implemented using
   ActiveRecord on RDB. :core uses the wallet that bundled with Tapyrus Core.
   
2. Contracts  
   You can use some smart contracts easily  
   - [Timestamp](#Timestamp): Record any data as a timestamp to a tapyrus blockchain.
   - [Payment](./lib/glueby/contract/payment.rb): Transfer TPC.
   - [Token](./lib/glueby/contract/token.rb): Issue, transfer and burn colored coin.

3. Sync blocks with your application   
   You can use BlockSyncer when you need to synchronize the state of an application with the state of a blockchain.  
   See more details at [BlockSyncer](./lib/glueby/block_syncer.rb).

4. Take over tx sender's fees  
   FeeProvider module can bear payments of sender's fees. You should provide funds for fees to FeeProvider before use.  
   See how to set up at [Use fee provider mode](#use-fee-provider-mode)

5. Utxo Provider
   The UtxoProvider allows users to create a variety of transactions without having to manage the TPCs they hold in their wallets.
   See more details at [Use utxo provider](#use-utxo-provider)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'glueby'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install glueby

### Setup for Ruby on Rails application development

1. Add this line to your application's Gemfile

    ```ruby
    gem 'glueby'
    ```

    and then execute 
    
        $ bundle install

2. Run installation rake task

        $ rails glueby:contract:install

3. Run Tapyrus Core as dev mode

    We recommend to run as a Docker container. 
    Docker image is here.

    * [tapyus/tapyrusd](https://hub.docker.com/repository/docker/tapyrus/tapyrusd)

    Starts tapryusd container

        $ docker run -d --name 'tapyrus_node_dev' -p 12381:12381 -e GENESIS_BLOCK_WITH_SIG='0100000000000000000000000000000000000000000000000000000000000000000000002b5331139c6bc8646bb4e5737c51378133f70b9712b75548cb3c05f9188670e7440d295e7300c5640730c4634402a3e66fb5d921f76b48d8972a484cc0361e66ef74f45e012103af80b90d25145da28c583359beb47b21796b2fe1a23c1511e443e7a64dfdb27d40e05f064662d6b9acf65ae416379d82e11a9b78cdeb3a316d1057cd2780e3727f70a61f901d10acbe349cd11e04aa6b4351e782c44670aefbe138e99a5ce75ace01010000000100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100f2052a010000001976a91445d405b9ed450fec89044f9b7a99a4ef6fe2cd3f88ac00000000' tapyrus/tapyrusd:v0.5.1

4. Modify the glueby configuration

    ```ruby
    # Use tapyrus dev network
    Tapyrus.chain_params = :dev
    Glueby.configure do |config|
      config.wallet_adapter = :activerecord
      # Modify rpc connection info in config/initializers/glueby.rb that is created in step 3.
      config.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12381, user: 'rpcuser', password: 'rpcpassword' }
    end
    ```

5. Generate db migration files for wallet feature

    These are essential if you use `config.wallet_adapter = :activerecord` configuration. 

        $ rails g glueby:contract:block_syncer
        $ rails g glueby:contract:wallet_adapter

    If you want to use token or timestamp, you need to do below generators.

        $ rails g glueby:contract:token
        $ rails g glueby:contract:timestamp

    Then, run the migrations.

        $ rails db:migrate

### Provide initial TPC (Tapyrus Coin) to wallets

To use contracts, wallets need to have TPC and it can be provided from coinbase tx.

1. Create a wallet and get receive address 

    ```ruby
    wallet = Glueby::Wallet.create
    wallet.balances # => {}
    address = wallet.internal_wallet.receive_address
    puts address
    ```

2. Generate a block

    Set an address you got in previous step to `[Your address]`

        $ docker exec tapyrus_node_dev tapyrus-cli -conf=/etc/tapyrus/tapyrus.conf generatetoaddress 1 "[Your address]" "cUJN5RVzYWFoeY8rUztd47jzXCu1p57Ay8V7pqCzsBD3PEXN7Dd4"

3. Sync blocks if you use `:activerecord` wallet adapter

    You don't need to do this if you are using `:core` wallet_adapter.

        $ rails glueby:contract:block_syncer:start

   Here the wallet created in step 1 have 50 TPC and you can see like this:

    ```ruby
    wallet.balances # =>  {""=>5000000000}
    ```

    TPC amount is shown as tapyrus unit. 1 TPC = 100000000 tapyrus.

## Timestamp

```ruby

Glurby.configure do |config|
  config.wallet_adapter = :activerecord
  config.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' }
end

wallet = Glueby::Wallet.create
timestamp = Glueby::Contract::Timestamp.new(wallet: wallet, content: "\x01\x02\x03")
timestamp.save!
# "a01eace94ce6cdc30f389609de8a7584a4e208ee82fec33a2f5875b7cee47097"

```

We can see the timestamp transaction using getrawblockchain command

```bash
> tapyrus-cli -rpcport=12381 -rpcuser=user -rpcpassword=pass getrawtransaction a01eace94ce6cdc30f389609de8a7584a4e208ee82fec33a2f5875b7cee47097 1

{
  "txid": "a01eace94ce6cdc30f389609de8a7584a4e208ee82fec33a2f5875b7cee47097",
  "hash": "a559a84d94cff58619bb735862eb93ff7a3b8fe122a8f2f4c10b7814fb15459a",
  "features": 1,
  "size": 234,
  "vsize": 234,
  "weight": 936,
  "locktime": 0,
  "vin": [
    {
      "txid": "12658e0289da70d43ae3777a174ac8c40f89cbe6564ed6606f197764b3556200",
      "vout": 0,
      "scriptSig": {
        "asm": "3044022067285c57a57fc0d7f64576abbec65639b0f4a8c31b5605eefe881edccb97c62402201ddec93c0c9bf3bb5707757e97e7fa6566c0183b41537e4f9ec46dcfe401864d[ALL] 03b8ad9e3271a20d5eb2b622e455fcffa5c9c90e38b192772b2e1b58f6b442e78d",
        "hex": "473044022067285c57a57fc0d7f64576abbec65639b0f4a8c31b5605eefe881edccb97c62402201ddec93c0c9bf3bb5707757e97e7fa6566c0183b41537e4f9ec46dcfe401864d012103b8ad9e3271a20d5eb2b622e455fcffa5c9c90e38b192772b2e1b58f6b442e78d"
      },
      "sequence": 4294967295
    }
  ],
  "vout": [
    {
      "value": 0.00000000,
      "n": 0,
      "scriptPubKey": {
        "asm": "OP_RETURN 039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81",
        "hex": "6a20039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81",
        "type": "nulldata"
      }
    },
    {
      "value": 49.99990000,
      "n": 1,
      "scriptPubKey": {
        "asm": "OP_DUP OP_HASH160 3c0422f624f2503193c7413eff32839b9e151b54 OP_EQUALVERIFY OP_CHECKSIG",
        "hex": "76a9143c0422f624f2503193c7413eff32839b9e151b5488ac",
        "reqSigs": 1,
        "type": "pubkeyhash",
        "addresses": [
          "16ULVva73ZhQiZu9o3njXc3TZ3aSog7FQQ"
        ]
      }
    }
  ],
  "hex": "0100000001006255b36477196f60d64e56e6cb890fc4c84a177a77e33ad470da89028e6512000000006a473044022067285c57a57fc0d7f64576abbec65639b0f4a8c31b5605eefe881edccb97c62402201ddec93c0c9bf3bb5707757e97e7fa6566c0183b41537e4f9ec46dcfe401864d012103b8ad9e3271a20d5eb2b622e455fcffa5c9c90e38b192772b2e1b58f6b442e78dffffffff020000000000000000226a20039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81f0ca052a010000001976a9143c0422f624f2503193c7413eff32839b9e151b5488ac00000000",
  "blockhash": "d33efc626114f89445d12c27f453c209382a3cb49de132bf978449093f2d2dbb",
  "confirmations": 3,
  "time": 1590822803,
  "blocktime": 1590822803
}
```

### Rails support

Glueby supports ruby on rails integration.

To use in rails, Add dependency to Gemfile.

Then invoke install task.

```
bin/rails glueby:contract:install
```

Install task creates a file `glueby.rb` in `config/initializers` directory like this.

```ruby
# Edit configuration for connection to tapyrus core
Glueby.configure do |config|
  config.wallet_adapter = :activerecord
  config.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' }
end

# Uncomment next line when using timestamp feature
# Glueby::BlockSyncer.register_syncer(Glueby::Contract::Timestamp::Syncer)
```

If you use timestamp feature, use `glueby:contract:timestamp` generator.

```
bin/rails g glueby:contract:timestamp
    create  db/migrate/20200613065511_create_timestamp.rb
bin/rails db:migrate
== 20200613065511 CreateTimestamp: migrating ==================================
-- create_table(:timestamps)
   -> 0.0023s
== 20200613065511 CreateTimestamp: migrated (0.0024s) =========================
```

Now, Glueby::Contract::AR::Timestamp model is available

```ruby
irb(main):001:0> wallet = Glueby::Wallet.create
=> #<Glueby::Wallet:0x00007fe8333f7d98 @internal_wallet=#<Glueby::Internal::Wallet:0x00007fe8333f7dc0 @id="70a58204a7f4cb10d973b762f17fdb4b">>
irb(main):003:0> t = Glueby::Contract::AR::Timestamp.new(wallet_id: wallet.id, content:"\x01010101", prefix: "app")
   (0.5ms)  SELECT sqlite_version(*)
=> #<Glueby::Contract::AR::Timestamp id: nil, txid: nil, status: "init", content_hash: "9ccc644b03a88358a754962903a659a2d338767ee61674dde5...", prefix: "app", wallet_id: "70a58204a7f4cb10d973b762f17fdb4b">
irb(main):004:0> t.save
   (0.1ms)  begin transaction
  Glueby::Contract::AR::Timestamp Create (0.4ms)  INSERT INTO "timestamps" ("status", "content_hash", "prefix", "wallet_id") VALUES (?, ?, ?, ?)  [["status", 0], ["content_hash", "9ccc644b03a88358a754962903a659a2d338767ee61674dde5434702a6256e6d"], ["prefix", "app"], ["wallet_id", "70a58204a7f4cb10d973b762f17fdb4b"]]
   (2.1ms)  commit transaction
=> true
```

After create timestamp model, run `glueby:contract:timestamp:create` task to broadcast the transaction to the Tapyrus Core Network and update status(init -> unconfirmed).

```
bin/rails glueby:contract:timestamp:create
broadcasted (id=1, txid=8d602ca8ebdd50fa70b5ee6bc6351965b614d0a4843adacf9f43fedd7112fbf4)
```

Run `glueby:block_syncer:start` task to confirm the transaction and update status(unconfirmed -> confirmded).

```
bin/rails glueby:block_syncer:start
```

## Use fee provider mode

Glueby contracts have two different way of fee provisions.

1. `:sender_pays_itself`
2. `:fee_provider_bears`

The first one: `:sender_pays_itself`, is the default behavior.
In the second Fee Provider mode, the Fee Provider module pays a fee instead of the transaction's sender.

### Fee Provider Specification

* Fee Provider pays fixed amount fee, and it is configurable.
* Fee Provider needs to have enough funds into their wallet.
* Fee Provider is managed to keep some number of UTXOs that have fixed fee value by rake tasks.

### Setting up Fee Provider

1. Set like below

```ruby
Glueby.configure do |config|
  # Use FeeProvider to supply inputs for fees on each transaction that is created on Glueby.
  config.fee_provider_bears!
  config.fee_provider_config = {
    # The fee that Fee Provider pays on each transaction.
    fixed_fee: 1000,
    # Fee Provider tries to keep the number of utxo in utxo pool as this size using `glueby:fee_provider:manage_utxo_pool` rake task
    # This size should not be greater than 2000.
    utxo_pool_size: 20 
  }
end
```

2. Deposit TPC into Fee Provider's wallet

Get an address from the wallet.

```
$ bundle exec rake glueby:fee_provider:address
mqYTLdLCUCCZkTkcpbVx1GqpvV1gK4euRD
```

Send TPC to the address.

If you use `Glueby::Contract::Payment` to the sending, you can do like this:

```ruby
Glueby::Contract::Payment.transfer(sender: sender, receiver_address: 'mqYTLdLCUCCZkTkcpbVx1GqpvV1gK4euRD', amount: 1_000_000)
```

3. Manage UTXO pool

The Fee Provider's wallet has to keep some UTXOs with `fixed_fee` amount for paying fees using `manage_utxo_pool` rake task below.
This rake task tries to split UTOXs up to `utxo_pool_size`. If the pool has more than `utxo_pool_size` UTXOs, it does nothing.

```
$ bundle exec rake glueby:fee_provider:manage_utxo_pool
Status: Ready
TPC amount: 999_000
UTXO pool size: 20

Configuration:
  fixed_fee = 1_000
  utxo_pool_size = 20
```

This shows that the UTXO pool has 20 UTXOs with `fixed_fee` amount for paying fees and has other UTXOs that never use for paying fees.
The sum of all the UTXOs that includes both kinds of UTXO is 999_000 tapyrus.

If the wallet doesn't have enough amount, the rake task shows an error like:

```
$ bundle exec rake glueby:fee_provider:manage_utxo_pool
Status: Insufficient Amount
TPC amount: 15_000
UTXO pool size: 15

1. Please replenishment TPC which is for paying fee to FeeProvider. 
   FeeProvider needs 21000 tapyrus at least for paying 20 transaction fees. 
   FeeProvider wallet's address is '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

Configuration:
  fixed_fee = 1_000
  utxo_pool_size = 20
```

If you want to get the status information, you can use the `status` task.

```
$ bundle exec rake glueby:fee_provider:status
Status: Ready
TPC amount: 999_000
UTXO pool size: 20

Configuration:
  fixed_fee = 1_000
  utxo_pool_size = 20
```

## Use Utxo Provider

UtxoProvider will pay TPC on behalf of the user.

TPCs are required to create transactions in many cases where Glueby is used, such as issuing tokens or recording timestamps.
However, on the other hand, each user may not want to fund or manage TPCs.

The UtxoProvider allows users to create a variety of transactions without having to manage the TPCs they hold in their wallets.

### Set up Utxo Provider

1. Configure using Glueby.configure

```ruby
Glueby.configure do |config|
  # using Utxo Provider
  config.enable_utxo_provider!

  # If not using Utxo Provider and each wallet manages TPCs by itself (Default behavior)
  # config.disable_utxo_provider!

  config.utxo_provider_config = {
    # The amount that each utxo in utxo pool posses.
    default_value: 1_000,
    # The number of utxos in utxo pool. This size should not be greater than 2000.
    utxo_pool_size: 20
  }
end
```

2. Deposit TPC into Utxo Provider's wallet

Get an address from the wallet, and send enough TPCs to the address.

```
$ bundle exec rake glueby:utxo_provider:address
mqYTLdLCUCCZkTkcpbVx1GqpvV1gK4euRD
```

3. Manage UTXO pool

Run the rake task `glueby:utxo_provider:manage_utxo_pool`
This rake task tries to split UTOXs up to `utxo_pool_size`. If the pool has more than `utxo_pool_size` UTXOs, it does nothing

```
$ bundle exec rake glueby:utxo_provider:manage_utxo_pool

Status: Ready
TPC amount: 4_999_990_000
UTXO pool size: 20

Configuration:
  default_value = 1_000
  utxo_pool_size = 20
```

If you want to get the status information, you can use the `status` task.

```
$ bundle exec rake glueby:utxo_provider:status
Status: Ready  q
TPC amount: 4_999_990_000
UTXO pool size: 20

Configuration:
  default_value = 1_000
  utxo_pool_size = 20

```

## Other configurations

### Default fixed fee for the FeeEstimator::Fixed

The architecture of Glueby accepts any fee estimation strategies for paying transactions fee. However, we officially support only one strategy: the fixed fee strategy to contract transactions.
It just returns a fixed fee value without any estimation.
Here provides a configuration to modify the default fixed fee value it returns like this:

```ruby
Glueby.configure do |config|
   config.default_fixed_fee = 10_000
end
```

### Default fee rate for the FeeEstimator::Auto

Glueby provide automate fee estimator `Glueby::Contract::FeeEstimator::Auto` that calculate minimum fee possible to broadcast from fee rate and tx size.
This method can be used in UTXO provider's management task so far. In other place where creates txs is not tested with this yet.

Here provides a configuration to modify the default fee rate it returns like this:

```ruby
Glueby.configure do |config|
   config.default_fee_rate = 1_000
end
```

## Error handling

Glueby has base error classes like `Glueby::Error` and `Glueby::ArgumentError`.
`Glueby::Error` is the base class for the all errors that are raises in the glueby.
`Glueby::ArgumentError` is the error class for argument errors in public contracts. This notifies the arguments is something wrong to glueby library user-side.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/glueby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/tapyrus-contractrb/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Glueby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/glueby/blob/master/CODE_OF_CONDUCT.md).
