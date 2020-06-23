# Tapyrus::Contract

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/tapyrus/contractrb`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tapyrus-contract'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install tapyrus-contract

## Rails support

Tapyrus contract library supports ruby on rails integration.

To use in rails, Add dependency to Gemfile.

Then invoke install task.
```
bin/rails tapyrus:contract:install
```

Install task creates a file `tapyrus_contract.rb` in `config/initializers` directory like this.
```
require 'tapyrus'
# Edit configuration for connection to tapyrus core
config = {schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'}
Tapyrus::Contract::RPC.configure(config)

# Edit seed for the master key
Tapyrus::Contract::Account.set_master_key(seed: ENV['TAPYRUS_CONTRACT_MASTER_KEY_SEED'])
```

## Usage

tapyrus-contractrb has below features.

* [Timestamp](#Timestamp)
* [Account](#Account)

### Timestamp  

```ruby

config = {schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'}
Tapyrus::Contract::RPC.configure(config)

timestamp = Tapyrus::Contract::Timestamp.new(content: "\x01\x02\x03")
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

If you use timestamp feature, use `tapyrus:contract:timestamp` generator.
```
bin/rails g tapyrus:contract:timestamp
    create  db/migrate/20200613065511_create_timestamp.rb
bin/rails db:migrate
== 20200613065511 CreateTimestamp: migrating ==================================
-- create_table(:timestamps)
   -> 0.0023s
== 20200613065511 CreateTimestamp: migrated (0.0024s) =========================
```

Now, Tapyrus::Contract::AR::Timestamp model is available

```ruby
irb(main):001:0> t = Tapyrus::Contract::AR::Timestamp.new(content:"\x01010101", prefix: "app")
   (0.4ms)  SELECT sqlite_version(*)
=> #<Tapyrus::Contract::AR::Timestamp id: nil, txid: nil, vout: nil, status: "init", content_hash: "9ccc644b03a88358a754962903a659a2d338767ee61674dde5...", prefix: "app">
irb(main):002:0> t.save
   (0.1ms)  begin transaction
  Tapyrus::Contract::AR::Timestamp Create (0.7ms)  INSERT INTO "timestamps" ("status", "content_hash", "prefix") VALUES (?, ?, ?)  [["status", 0], ["content_hash", "9ccc644b03a88358a754962903a659a2d338767ee61674dde5434702a6256e6d"], ["prefix", "app"]]
   (2.3ms)  commit transaction
=> true
```

After create timestamp model, run `tapyrus:contract:timestamp:create` task to broadcast the transaction to the Tapyrus Core Network and update status(init -> unconfirmed).

```
bin/rails tapyrus:contract:timestamp:create
broadcasted (id=1, txid=8d602ca8ebdd50fa70b5ee6bc6351965b614d0a4843adacf9f43fedd7112fbf4)
```

Run `tapyrus:contract:timestamp:confirm` task to confirm the transaction and update status(unconfirmed -> confirmded).
```
bin/rails tapyrus:contract:timestamp:confirm
confirmed (id=1, txid=8d602ca8ebdd50fa70b5ee6bc6351965b614d0a4843adacf9f43fedd7112fbf4)
```

### Account

Account feature makes your rails app possible to manage Tapyrus account according to [BIP-0044](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki).

#### Setup

Create migration file for Account feature and do migration task 'db:migrate'.

```
bin/rails g tapyrus:contract:account
    create  db/migrate/20200623042936_create_account.rb
bin/rails db:migrate
```

Then set master key seed to env `TAPYRUS_CONTRACT_MASTER_KEY_SEED`.

Here is an exmaple to generate a brand new master key.
```ruby
require 'tapyrus'

Tapyrus::Wallet::MasterKey.generate # => #<Tapyrus::Wallet::MasterKey:0x00007f...>
```

#### Example

```ruby
# Create a new account.
account = Tapyrus::Contract::Account.create!(name: 'example') # => #<Tapyrus::Contract::Account:0x00...>

# Create keys
receive_key = account.create_receive # => #<Tapyrus::ExtKey:0x00...>
change_key = account.create_change # => #<Tapyrus::ExtKey:0x00...>

# Get derived keys
receive_keys = account.derived_receive_keys # => [#<Tapyrus::ExtPubkey:0x00...>]
change_keys = account.derived_change_keys # => [#<Tapyrus::ExtPubkey:0x00...>]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/tapyrus-contractrb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/tapyrus-contractrb/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tapyrus::Contractrb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/tapyrus-contractrb/blob/master/CODE_OF_CONDUCT.md).
