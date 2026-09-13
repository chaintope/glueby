RSpec.describe 'Glueby::Internal::RPC' do
  let(:config) { { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' } }

  before do
    allow_any_instance_of(Tapyrus::RPC::TapyrusCoreClient).to receive(:request).with(:help).and_return("")
    @config_before_example = Glueby::Internal::RPC.instance_variable_get(:@config)
    Glueby::Internal::RPC.configure(config)
  end

  after do
    Glueby::Internal::RPC.configure(@config_before_example)
  end

  describe 'configure' do
    # 設定を入れ直したら、以後のクライアントは新しい接続先を使う
    it 'builds the client from the latest config' do
      client_before_reconfigure = Glueby::Internal::RPC.client
      Glueby::Internal::RPC.configure(config.merge(port: 12382))

      expect(Glueby::Internal::RPC.client).not_to equal(client_before_reconfigure)
      expect(Glueby::Internal::RPC.client.config[:port]).to eq 12382
    end
  end

  describe 'client' do
    # 生成に時間がかかる状況を作り、その最中に別のスレッドが割り込めるようにする
    let(:building) { Queue.new }
    let(:may_finish) { Queue.new }
    let(:build_count) { Queue.new }

    before do
      allow_any_instance_of(Tapyrus::RPC::TapyrusCoreClient).to receive(:request).with(:help) do
        build_count.push(true)
        building.push(true)
        may_finish.pop(timeout: 5)
        ""
      end
    end

    # 生成中に他のスレッドが呼んでも、共有クライアントは 1 つしか作らない
    it 'builds the shared client once when another thread asks for it during the build' do
      builder = Thread.new { Glueby::Internal::RPC.client }
      expect(building.pop(timeout: 5)).to be true

      waiter_started = Queue.new
      waiter = Thread.new do
        waiter_started.push(true)
        Glueby::Internal::RPC.client
      end
      expect(waiter_started.pop(timeout: 5)).to be true
      expect(waiter.join(0.2)).to be_nil # 生成が終わるまで待たされる

      may_finish.push(true)

      expect(builder.value).to equal(waiter.value)
      expect(build_count.size).to eq 1
    end

    # 生成中に設定を入れ直しても、捨てたはずの古い設定のクライアントは残らない
    it 'does not keep a client built from a config that configure has replaced' do
      builder = Thread.new { Glueby::Internal::RPC.client }
      expect(building.pop(timeout: 5)).to be true

      reconfigure_started = Queue.new
      reconfigure = Thread.new do
        reconfigure_started.push(true)
        Glueby::Internal::RPC.configure(config.merge(port: 12382))
      end
      expect(reconfigure_started.pop(timeout: 5)).to be true
      expect(reconfigure.join(0.2)).to be_nil # 生成が終わるまで待たされる

      may_finish.push(true)
      [builder, reconfigure].each { |thread| expect(thread.join(5)).to equal(thread) }

      may_finish.push(true) # 作り直しの分
      expect(Glueby::Internal::RPC.client.config[:port]).to eq 12382
    end
  end

  describe 'perform_as' do
    let(:wallet_name) { 'wallet' }

    it 'yields a client bound to the wallet' do
      Glueby::Internal::RPC.perform_as(wallet_name) do |client|
        expect(client.config[:wallet]).to eq wallet_name
      end
    end

    it 'yields a client that keeps the connection settings' do
      Glueby::Internal::RPC.perform_as(wallet_name) do |client|
        expect(client.config).to include(config)
      end
    end

    # ウォレットを指定しない RPC が使う共有クライアントは、ブロックの内外どちらでも書き換えない
    it 'leaves the shared client unbound' do
      Glueby::Internal::RPC.perform_as(wallet_name) do |client|
        expect(Glueby::Internal::RPC.client.config[:wallet]).to be_nil
      end

      expect(Glueby::Internal::RPC.client.config[:wallet]).to be_nil
    end

    it 'returns the value the block returns' do
      rt = Glueby::Internal::RPC.perform_as(wallet_name) { 'Return value of the block' }

      expect(rt).to eq 'Return value of the block'
    end

    # 呼び出しごとに別のクライアントを渡すため、ある呼び出しの設定が他へ漏れない
    it 'yields a different client on every call' do
      first = Glueby::Internal::RPC.perform_as(wallet_name) { |client| client }
      second = Glueby::Internal::RPC.perform_as(wallet_name) { |client| client }

      expect(second).not_to equal(first)
      expect(second).not_to equal(Glueby::Internal::RPC.client)
    end

    # 設定を凍結して、書き換えがその場で分かるようにする
    it 'freezes the config of the yielded client' do
      Glueby::Internal::RPC.perform_as(wallet_name) do |client|
        expect { client.config[:wallet] = 'another-wallet' }.to raise_error(FrozenError)
      end
    end

    # ウォレットが未ロードでもクライアントの用意では失敗しない。失敗は呼び出し側のブロックで起きるので、
    # 呼び出し側が自分の RPC のエラーとして扱える
    it 'yields without calling any RPC even when the wallet is not loaded' do
      Glueby::Internal::RPC.client # 共有クライアントは先に用意しておく
      wallet_not_found = Tapyrus::RPC::Error.new(500, nil, { 'code' => -18, 'message' => 'Requested wallet does not exist or is not loaded' })
      allow_any_instance_of(Tapyrus::RPC::TapyrusCoreClient).to receive(:request).and_raise(wallet_not_found)

      expect { |block| Glueby::Internal::RPC.perform_as('unloaded-wallet', &block) }.to yield_control
    end

    it 'keeps each thread bound to its own wallet while another thread performs as a different wallet' do
      a_entered = Queue.new
      b_entered = Queue.new
      handoff = {}
      seen = {}

      thread_a = Thread.new do
        Glueby::Internal::RPC.perform_as('wallet-a') do |client|
          a_entered.push(true)
          # スレッド B が自分のウォレットに切り替えるのを待ってから、自分のウォレットを読む
          handoff[:b_entered] = b_entered.pop(timeout: 5)
          seen[:a] = client.config[:wallet]
        end
      end

      thread_b = Thread.new do
        handoff[:a_entered] = a_entered.pop(timeout: 5)
        Glueby::Internal::RPC.perform_as('wallet-b') do |client|
          b_entered.push(true)
          # スレッド A がブロックを抜けるのを待ってから、自分のウォレットを読む
          handoff[:a_finished] = thread_a.join(5)
          seen[:b] = client.config[:wallet]
        end
      end

      [thread_a, thread_b].each { |thread| expect(thread.join(5)).to equal(thread) }

      # 待ち合わせが時間切れになっていない、つまり 2 つのスレッドが実際に交錯したことを確かめる
      expect(handoff).to eq(a_entered: true, b_entered: true, a_finished: thread_a)
      expect(seen).to eq(a: 'wallet-a', b: 'wallet-b')
    end

    context 'raise an error on the RPC calling' do
      it 'propagates the error the block raises' do
        expect do
          Glueby::Internal::RPC.perform_as(wallet_name) do
            raise RuntimeError, 'an error'
          end
        end.to raise_error(RuntimeError, 'an error')
      end
    end
  end
end
