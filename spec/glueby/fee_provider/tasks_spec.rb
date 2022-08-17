RSpec.describe Glueby::FeeProvider::Tasks, active_record: true do
  let(:tasks) { described_class.new }
  let(:wallet) { TestInternalWallet.new }
  let(:unspents) { [] }
  let(:balance) { 0 }
  let(:config) { {} }

  before do
    Glueby::FeeProvider.configure(config)
    allow(Glueby::Internal::Wallet).to receive(:load).and_return(wallet)
    fee_provider = Glueby::FeeProvider.new
    tasks.instance_variable_set(:@fee_provider, fee_provider)

    allow(wallet).to receive(:list_unspent).and_return(unspents)
    allow(wallet).to receive(:balance).and_return(balance)
  end

  describe 'manage_utxo_pool' do
    subject { tasks.manage_utxo_pool }

    context 'UTXO pool is empty' do
      context 'The wallet has enough TPC amount' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 15_000,
            finalized: true
          }]
        end
        let(:balance) { 25_000 }

        it 'makes the pool full' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.inputs.count).to eq(2)
            expect(tx.inputs[0].out_point).to eq(Tapyrus::OutPoint.from_txid('5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5', 0))

            expect(tx.outputs.count).to eq(21) # default UTXO pool size + a change output
            expect(tx.outputs[0...20].map(&:value).uniq).to eq([1_000])
            # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
            expect(tx.outputs[20].value).to eq(25_000 - 20 * 1_000 - 1_000)
          end
          expect(tasks).to receive(:status)
          subject
        end

        context 'fixed_fee option is specified' do
          let(:config) { { fixed_fee: 800} }

          it 'creates 800 tapyrus value outputs' do
            expect(wallet).to receive(:broadcast) do |tx|
              expect(tx.outputs[0...20].map(&:value).uniq).to eq([800])
              # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
              expect(tx.outputs[20].value).to eq(25_000 - 20 * 800 - 800)
            end
            expect(tasks).to receive(:status)
            subject
          end
        end

        context 'utxo_pool_size option is specified' do
          let(:config) { { utxo_pool_size: 10 } }

          it 'creates 10 outputs' do
            expect(wallet).to receive(:broadcast) do |tx|
              expect(tx.outputs.count).to eq(11)
              expect(tx.outputs[0...10].map(&:value).uniq).to eq([1_000])
              # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
              expect(tx.outputs[10].value).to eq(25_000 - 10 * 1_000 - 1_000)
            end
            expect(tasks).to receive(:status)
            subject
          end
        end
      end

      context 'The wallet has no TPC' do
        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::FeeProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end

      context 'The wallet has some money but it is not enough to fill the UTXO pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 11_000,
            finalized: true
          }]
        end
        let(:balance) { 11_000 }

        it 'creates 9 fee outputs' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.outputs[0...9].map(&:value).uniq).to eq([1_000])
            # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
            expect(tx.outputs[9].value).to eq(11_000 - 9 * 1_000 - 1_000)
          end
          expect(tasks).to receive(:status)
          subject
        end
      end

      context 'change output is dust' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 11_500,
            finalized: true
          }]
        end
        let(:balance) { 21_500 }

        it 'removes change output from transaction' do
          # amount of change output is 21,500 - 20 * 1,000 - 1,000 = 500(tapyrus), which is `dust` output
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.outputs.count).to eq(20) # default pool size
            expect(tx.outputs[0...20].map(&:value).uniq).to eq([1_000]) # a change output is removed
          end
          subject
        end
      end
    end

    context 'The UTXO pool has some outputs but it is not full' do
      let(:pool_outputs) do
        3.times.map do |i|
          {
            txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
            vout: i,
            script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
            amount: 1_000,
            finalized: true
          }
        end
      end

      context 'The wallet has enough TPC amount' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 15_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 28_000 }

        it 'fills the UTXO pool' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.inputs.count).to eq(2)
            expect(tx.inputs[0].out_point).to eq(Tapyrus::OutPoint.from_txid('5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5', 0))

            # outputs count should be default UTXO pool size - existing fee output + a change output
            expect(tx.outputs.count).to eq(18)
            expect(tx.outputs[0...17].map(&:value).uniq).to eq([1_000])
            # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
            expect(tx.outputs[17].value).to eq(25_000 - 17 * 1_000 - 1_000)
          end
          expect(tasks).to receive(:status)
          subject
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) do
          pool_outputs
        end

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::FeeProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end

      context 'The wallet has some money but it is not enough to fill the UTXO pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 11_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 11_000 }

        it 'creates 9 outputs' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.outputs[0...9].map(&:value).uniq).to eq([1_000])
            # The change output's value should equal to <before amount> - <UTXO pool size> * <fixed fee> - <fee of the tx>
            expect(tx.outputs[9].value).to eq(11_000 - 9 * 1_000 - 1_000)
          end
          expect(tasks).to receive(:status)
          subject
        end
      end
    end

    context 'pool is full' do
      let(:pool_outputs) do
        20.times.map do |i|
          {
            txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
            vout: i,
            script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
            amount: 1_000,
            finalized: true
          }
        end
      end

      context 'The wallet has enough TPC amount' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 15_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 28_000 }

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::FeeProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) do
          pool_outputs
        end

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::FeeProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end

      context 'The wallet has some money but it is not enough to fill the UTXO pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_100,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 10_100 }

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::FeeProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end
    end
  end

  describe 'status' do
    subject { tasks.status }
    context 'UTXO pool is full' do

      let(:pool_outputs) do
        20.times.map do |i|
          {
            txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
            vout: i,
            script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
            amount: 1_000,
            finalized: true
          }
        end
      end

      context 'The wallet has enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 100_000_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 100_020_000 }

        it 'shows ready' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Ready
          TPC amount: 100_020_000
          UTXO pool size: 20

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet doesn\'t have enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 30_000 }

        it 'shows ready' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Ready
          TPC amount: 30_000
          UTXO pool size: 20

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) { pool_outputs }
        let(:balance) { 20_000 }

        it 'shows ready' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Ready
          TPC amount: 20_000
          UTXO pool size: 20

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end
    end

    context 'UTXO pool is not full' do
      let(:pool_outputs) do
        10.times.map do |i|
          {
            txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
            vout: i,
            script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
            amount: 1_000,
            finalized: true
          }
        end
      end

      context 'The wallet has enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 100_000_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 100_010_000 }

        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Ready
          TPC amount: 100_010_000
          UTXO pool size: 10

          Please create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet doesn\'t have enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 20_000 }

        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Insufficient Amount
          TPC amount: 20_000
          UTXO pool size: 10

          1. Please replenishment TPC which is for paying fee to FeeProvider. 
             FeeProvider needs 21000 tapyrus at least for paying 20 transaction fees. 
             FeeProvider wallet's address is '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
          2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) { pool_outputs }
        let(:balance) { 10_000 }

        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Insufficient Amount
          TPC amount: 10_000
          UTXO pool size: 10

          1. Please replenishment TPC which is for paying fee to FeeProvider. 
             FeeProvider needs 21000 tapyrus at least for paying 20 transaction fees. 
             FeeProvider wallet's address is '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
          2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end
    end

    context 'UTXO pool is empty' do
      context 'The wallet has enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 100_000_000,
            finalized: true
          }]
        end
        let(:balance) { 100_000_000 }

        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Not Ready
          TPC amount: 100_000_000
          UTXO pool size: 0

          Please create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet doesn\'t have enough TPC to fill the pool' do
        let(:unspents) do
          [{
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 10_000,
            finalized: true
          }]
        end
        let(:balance) { 10_000 }

        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Not Ready
          TPC amount: 10_000
          UTXO pool size: 0

          1. Please replenishment TPC which is for paying fee to FeeProvider. 
             FeeProvider needs 21000 tapyrus at least for paying 20 transaction fees. 
             FeeProvider wallet's address is '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
          2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end

      context 'The wallet has no TPC' do
        it 'shows ready and suggest to run mange_utxo_pool task' do
          expect { subject }.to output(<<~EOS).to_stdout
          Status: Not Ready
          TPC amount: 0
          UTXO pool size: 0

          1. Please replenishment TPC which is for paying fee to FeeProvider. 
             FeeProvider needs 21000 tapyrus at least for paying 20 transaction fees. 
             FeeProvider wallet's address is '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
          2. Then create UTXOs for paying in UTXO pool with 'rake glueby:fee_provider:manage_utxo_pool'

          Configuration:
            fixed_fee = 1_000
            utxo_pool_size = 20
          EOS
        end
      end
    end
  end

  describe 'print_address' do
    context "Show Fee Provider's address" do
      subject { tasks.print_address }

      it do
        expect { subject }.to output("1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT\n").to_stdout
      end
    end
  end
end