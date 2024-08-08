require 'socket'
require 'concurrent-ruby'
require 'benchmark'

class ThreadedWorker < Delayed::Worker
  MAX_RETRIES = 5

  def initialize(thread_count, options={})
    super(options)
    @thread_count = thread_count
    @stop_signal = Concurrent::AtomicBoolean.new(false)
    @pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: thread_count,
      max_threads: thread_count,
      max_queue: 0 # Unbounded queue
    )
  end

  def start
    trap_signals
    say "Starting multi-threaded job worker with #{@thread_count} threads"

    @thread_count.times do |i|
      @pool.post { threaded_work_off(i + 1) }
    end

    until @stop_signal.true?
      sleep(1) # Prevent a tight loop
    end

    say 'Shutting down...'
    @pool.shutdown
    @pool.wait_for_termination(30) # Wait up to 30 seconds for threads to complete like monit
    say 'All threads have finished. Exiting.'
  end

  # Getter for the base name
  def name
    Thread.current[:name] || @name
  end

  # Setter for the base name
  def name=(name)
    @name = name
    Thread.current[:name] = name
  end

  def stop_signal?
    @stop_signal.true?
  end

  private

  def threaded_work_off(thread_index)
    Thread.current[:name] = generate_thread_name(thread_index)
    retry_attempts = 0
    until stop_signal?
      begin
        runtime = Benchmark.realtime do
          @result = work_off(100)
        end

        count = @result[0] + @result[1]

        if count.zero?
          sleep(self.class.sleep_delay) unless stop_signal?
        else
          say sprintf("#{count} jobs processed at %.4f j/s, %d failed", count / runtime, @result.last)
        end

        retry_attempts = 0 # reset retries after a successful work_off
      rescue StandardError => e
        say "Worker thread encountered an error: #{e.message}. Retrying..."
        retry_attempts += 1
        if retry_attempts >= MAX_RETRIES
          say "Worker thread has failed #{retry_attempts} times. Exiting to prevent infinite loop."
          break
        end
        sleep(1) # Adding a delay before retrying
        retry
      end
    end
  end

  def generate_thread_name(thread_index)
    super_name = Delayed::Worker.instance_method(:name).bind(self).call
    "#{super_name} thread:#{thread_index}"
  end

  def trap_signals
    trap('TERM') { initiate_shutdown }
    trap('INT') { initiate_shutdown }
  end

  def initiate_shutdown
    Thread.new do
      say 'Initiating shutdown...'
      @stop_signal.make_true
    end.join
  end
end
