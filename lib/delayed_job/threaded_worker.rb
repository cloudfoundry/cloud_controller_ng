class ThreadedWorker < Delayed::Worker
  def initialize(thread_count, options={}, grace_period_seconds=30)
    super(options)
    @thread_count = thread_count
    @threads = []
    @unexpected_error = false
    @mutex = Mutex.new
    @grace_period_seconds = grace_period_seconds
  end

  def start
    # add quit trap as in QuitTrap monkey patch
    trap('QUIT') do
      Thread.new { say 'Exiting...' }
      stop
    end

    trap('TERM') do
      Thread.new { say 'Exiting...' }
      stop
      raise SignalException.new('TERM') if self.class.raise_signal_exceptions
    end

    trap('INT') do
      Thread.new { say 'Exiting...' }
      stop
      raise SignalException.new('INT') if self.class.raise_signal_exceptions && self.class.raise_signal_exceptions != :term
    end

    say "Starting threaded delayed worker with #{@thread_count} threads"

    @thread_count.times do |thread_index|
      thread = Thread.new do
        Thread.current[:thread_name] = "thread:#{thread_index + 1}"
        threaded_start
      rescue Exception => e # rubocop:disable Lint/RescueException
        @mutex.synchronize do
          say "Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}", 'error'
          @unexpected_error = true
        end
        stop
      end
      @mutex.synchronize do
        @threads << thread
      end
    end

    @threads.each(&:join)
  ensure
    raise 'Unexpected error occurred in one of the worker threads' if @unexpected_error
  end

  def name
    base_name = super
    thread_name = Thread.current[:thread_name]
    thread_name ? "#{base_name} #{thread_name}" : base_name
  end

  def stop
    Thread.new do
      say 'Shutting down worker threads gracefully...'
      super

      @threads.each do |t|
        Thread.new do
          t.join(@grace_period_seconds)
          if t.alive?
            say "Killing thread '#{t[:thread_name]}'"
            t.kill
          end
        end
      end.each(&:join) # Ensure all join threads complete
    end
  end

  def threaded_start
    self.class.lifecycle.run_callbacks(:execute, self) do
      loop do
        self.class.lifecycle.run_callbacks(:loop, self) do
          @realtime = Benchmark.realtime do
            @result = work_off
          end
        end

        count = @result[0] + @result[1]

        if count.zero?
          if self.class.exit_on_complete
            say 'No more jobs available. Exiting'
            break
          elsif !stop?
            sleep(self.class.sleep_delay)
            reload!
          end
        else
          say sprintf("#{count} jobs processed at %.4f j/s, %d failed", count / @realtime, @result.last)
        end
        break if stop?
      end
    end
  end
end
