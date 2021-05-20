# Glueby [![Build Status](https://travis-ci.org/chaintope/glueby.svg?branch=master)](https://travis-ci.org/chaintope/glueby) [![Gem Version](https://badge.fury.io/rb/glueby.svg)](https://badge.fury.io/rb/glueby) [![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/glueby`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'glueby'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install glueby

## Usage

Glueby has below features.

- [Timestamp](#Timestamp)

### Timestamp

```ruby

config = {adapter: 'core', schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'}
Glueby::Wallet.configure(config)

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

#### Rails support

Glueby supports ruby on rails integration.

To use in rails, Add dependency to Gemfile.

Then invoke install task.

```
bin/rails glueby:contract:install
```

Install task creates a file `glueby.rb` in `config/initializers` directory like this.

```
# Edit configuration for connection to tapyrus core
config = {adapter: 'core', schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'}
Glueby::Wallet.configure(config)
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

Run `glueby:contract:timestamp:confirm` task to confirm the transaction and update status(unconfirmed -> confirmded).

```
bin/rails glueby:contract:timestamp:confirm
confirmed (id=1, txid=8d602ca8ebdd50fa70b5ee6bc6351965b614d0a4843adacf9f43fedd7112fbf4)
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
Glueby.fee_mode = :fee_provider_bears
Glueby::FeeProvider.configure({
  # The fee that Fee Provider pays on each transaction.
  fixed_fee: 1000,
  # Fee Provider tries to keep the number of utxo in utxo pool as this size using `glueby:fee_provider:manage_utxo_pool` rake task
  utxo_pool_size: 20
})
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
  fixed_fee = 1000
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

Configuration:
  fixed_fee = 1000
  utxo_pool_size = 20
```

If you want to get the status information, you can use the `status` task.

```shell
$ bundle exec rake glueby:fee_provider:status
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/glueby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/tapyrus-contractrb/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Glueby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/glueby/blob/master/CODE_OF_CONDUCT.md).
