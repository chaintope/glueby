def on_multi_thread(count)
  threads = count.times.map do |i|
    Thread.new do
      yield(i)
    end
  end
  # Each value is Token object
  threads.map { |t| t.value }
end