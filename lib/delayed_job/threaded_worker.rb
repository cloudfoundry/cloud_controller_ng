module Delayed
  class ThreadedWorker < Delayed::Worker
    def initialize(options={})
      super
      @num_threads = options[:num_threads]
      @grace_period_seconds = options.key?(:grace_period_seconds) ? options[:grace_period_seconds] : 30
      @threads = []
      @unexpected_error = false
      @mutex = Mutex.new
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

      say "Starting threaded delayed worker with #{@num_threads} threads"

      @num_threads.times do |thread_index|
        thread = Thread.new do
          Thread.current[:thread_index] = thread_index
          threaded_start
        rescue Exception => e # rubocop:disable Lint/RescueException
          say "Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}", 'error'
          @mutex.synchronize { @unexpected_error = true }
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

    def names_with_threads
      base_name = name
      @num_threads.times.map { |thread_index| extended_name_with_thread_index(base_name, thread_index) }
    end

    def name
      extended_name_with_thread_index(super)
    end

    def stop
      Thread.new do
        say 'Shutting down worker threads gracefully...'
        super

        @threads.each do |t|
          Thread.new do
            t.join(@grace_period_seconds)
            if t.alive?
              say "Killing thread '#{t[:thread_index]}'"
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

    private

    def extended_name_with_thread_index(base_name, thread_index=nil)
      raise ArgumentError.new('base_name cannot be nil or empty') if base_name.nil? || base_name.empty?

      thread_index = Thread.current[:thread_index] if thread_index.nil?
      thread_name = "thread:#{thread_index + 1}" if thread_index.is_a? Integer

      return base_name if thread_name.nil?

      "#{base_name} #{thread_name}"
    end
  end
end
