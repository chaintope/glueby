def on_multi_thread(count)
  if ENV['DEBUG']
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.formatter = proc do |severity, datetime, progname, msg|
      thread_number = sprintf("%02d", Thread.current[:thread_number] || 0)
      "THREAD##{thread_number}, #{severity[0]}, [#{datetime.strftime('%Y-%m-%dT%H:%M:%S.%6N')} ##{Process.pid}] #{severity} -- : #{msg}\n"
    end
  end

  threads = count.times.map do |i|
    Thread.new(i) do |thread_number|
      Thread.current[:thread_number] = thread_number
      yield(thread_number)
    end
  end
  # Each value is Token object
  threads.map { |t| t.value }
end