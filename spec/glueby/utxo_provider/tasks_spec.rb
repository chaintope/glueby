RSpec.describe Glueby::UtxoProvider::Tasks, active_record: true do
  let(:tasks) { described_class.new }
  let(:wallet) { TestInternalWallet.new }
  let(:unspents) { [] }
  let(:balance) { 0 }
  let(:config) { {} }

  before do
    Glueby::UtxoProvider.configure(config)
    allow(Glueby::Internal::Wallet).to receive(:load).and_return(wallet)

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
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 2,
            amount: 10_000,
            finalized: true
          }]
        end
        let(:balance) { 35_000 }

        it 'makes the pool full' do
          # Never create the new address
          expect(wallet).not_to receive(:receive_address)

          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.inputs.count).to eq(3)
            expect(tx.inputs[0].out_point).to eq(Tapyrus::OutPoint.from_txid('5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5', 0))

            expect(tx.outputs.count).to eq(21) # default UTXO pool size + a change output
            expect(tx.outputs[0...20].map(&:value).uniq).to eq([1_000])
            expect(tx.outputs[20].value).to eq(35_000 - 20 * 1_000 - 10_000)
          end
          expect(tasks).to receive(:status)
          subject
        end

        context 'default_value option is specified' do
          context 'from config setting' do
            let(:config) { { default_value: 800} }

            it 'creates 800 tapyrus value outputs' do
              expect(wallet).to receive(:broadcast) do |tx|
                expect(tx.outputs[0...20].map(&:value).uniq).to eq([800])
                expect(tx.outputs[20].value).to eq(35_000 - 20 * 800 - 10_000)
              end
              expect(tasks).to receive(:status)
              subject
            end
          end

          context 'from system_informations table' do
            before do
              Glueby::AR::SystemInformation.create(
                info_key: 'utxo_provider_default_value',
                info_value: '700'
              )
            end

            it 'creates 700 tapyrus value outputs' do
              expect(wallet).to receive(:broadcast) do |tx|
                expect(tx.outputs[0...20].map(&:value).uniq).to eq([700])
                expect(tx.outputs[20].value).to eq(35_000 - 20 * 700 - 10_000)
              end
              expect(tasks).to receive(:status)
              subject
            end
          end
        end

        context 'utxo_pool_size option is specified' do
          context 'from config setting' do
            let(:config) { { utxo_pool_size: 10 } }

            it 'creates 10 outputs' do
              expect(wallet).to receive(:broadcast) do |tx|
                expect(tx.outputs.count).to eq(11)
                expect(tx.outputs[0...10].map(&:value).uniq).to eq([1_000])
                expect(tx.outputs[10].value).to eq(35_000 - 10 * 1_000 - 10_000)
              end
              expect(tasks).to receive(:status)
              subject
            end
          end

          context 'from system_informations table' do
            before do
              Glueby::AR::SystemInformation.create(
                info_key: 'utxo_provider_pool_size',
                info_value: '5'
              )
            end

            it 'creates 5 outputs' do
              expect(wallet).to receive(:broadcast) do |tx|
                expect(tx.outputs.count).to eq(6)
                expect(tx.outputs[0...5].map(&:value).uniq).to eq([1_000])
                expect(tx.outputs[5].value).to eq(35_000 - 5 * 1_000 - 10_000)
              end
              expect(tasks).to receive(:status)
              subject
            end
          end
        end

        context 'fee_estimator option is specified' do
          class TestFeeEstimator
            include Glueby::Contract::FeeEstimator
            def estimate_fee(tx)
              2_000
            end
          end

          let(:config) { { fee_estimator: TestFeeEstimator.new } }

          it 'creates 10 outputs' do
            expect(wallet).to receive(:broadcast) do |tx|
              expect(tx.outputs.count).to eq(21) # default UTXO pool size + a change output
              expect(tx.outputs[0...20].map(&:value).uniq).to eq([1_000])
              expect(tx.outputs[20].value).to eq(35_000 - 20 * 1_000 - 2_000)
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
              amount: 20_500,
              finalized: true
            }]
          end
          let(:balance) { 30_500 }

          it 'removes change output from transaction' do
            # amount of change output is 30,500 - 20 * 1,000 - 10,000 = 500(tapyrus), which is `dust` output
            expect(wallet).to receive(:broadcast) do |tx|
              expect(tx.outputs.count).to eq(20) # default UTXO pool size
              expect(tx.outputs[0...20].map(&:value).uniq).to eq([1_000]) # a change output is removed
            end
            subject
          end
        end
      end

      context 'The wallet has no TPC' do
        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::UtxoProvider::Tasks).to receive(:status)
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
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 15_600,
            finalized: true
          }]
        end
        let(:balance) { 25_600 }

        it 'creates 16 outputs' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.outputs.size).to eq 16
            expect(tx.outputs[0...14].map(&:value).uniq).to eq([1_000])
            # The change output's value should equal to <before amount> - <UTXO pool size> * <default value> - <fee of the tx>
            expect(tx.outputs[15].value).to eq(25_600 - 15 * 1_000 - 10_000)
          end
          expect(tasks).to receive(:status)
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
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
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
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 2,
            amount: 10_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 38_000 }

        it 'fills the UTXO pool' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.inputs.count).to eq(3)
            expect(tx.inputs[0].out_point).to eq(Tapyrus::OutPoint.from_txid('5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5', 0))

            expect(tx.outputs.count).to eq(18)
            expect(tx.outputs[0...17].map(&:value).uniq).to eq([1_000])
            expect(tx.outputs[17].value).to eq(35_000 - 17 * 1_000 - 10_000)
          end
          expect(tasks).to receive(:status)
          subject
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) { pool_outputs }

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::UtxoProvider::Tasks).to receive(:status)
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
            amount: 10_000,
            finalized: true
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 1,
            amount: 15_600,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 28_600 }

        it 'creates 16 outputs' do
          expect(wallet).to receive(:broadcast) do |tx|
            expect(tx.outputs.size).to eq 16
            expect(tx.outputs[0...14].map(&:value).uniq).to eq([1_000])
            expect(tx.outputs[15].value).to eq(25_600 - 15 * 1_000 - 10_000)
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
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            amount: 1_000,
            finalized: true
          }
        end
      end

      context 'The wallet has TPC amount' do
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
          }, {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 2,
            amount: 10_000,
            finalized: true
          }] + pool_outputs
        end
        let(:balance) { 38_000 }

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::UtxoProvider::Tasks).to receive(:status)
          expect(wallet).not_to receive(:broadcast)
          subject
        end
      end

      context 'The wallet has no TPC' do
        let(:unspents) { pool_outputs }

        it 'doesn\'t broadcast tx'  do
          expect_any_instance_of(Glueby::UtxoProvider::Tasks).to receive(:status)
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
            default_value = 1_000
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
            default_value = 1_000
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
            default_value = 1_000
            utxo_pool_size = 20
          EOS
        end
      end
    end
  end
   
  describe 'print_address' do
    subject { tasks.print_address }

    it do
      expect { subject }.to output("191arn68nSLRiNJXD8srnmw4bRykBkVv6o\n").to_stdout
    end
  end
end
