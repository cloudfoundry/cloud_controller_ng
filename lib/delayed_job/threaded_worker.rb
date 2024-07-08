require 'socket'

class ThreadedWorker < Delayed::Worker
  DEFAULT_THREAD_COUNT = 4

  def initialize(options={}, thread_count=DEFAULT_THREAD_COUNT)
    super(options)
    @thread_count = thread_count
    @threads = []
    @stop_signal = false
    @name_prefix = options[:worker_name] || 'worker'
  end

  def start
    trap_signals

    say 'Starting multi-threaded job worker'

    @thread_count.times do |i|
      thread_name = generate_thread_name(i + 1)
      @threads << Thread.new do
        thread_name(thread_name)
        threaded_work_off
      end
    end

    @threads.each(&:join) # Wait for threads to finish
  end

  def name
    Thread.current[:name] || @name
  end

  def name=(name)
    # Set the instance variable for compatibility && ensure thread-local storage is also updated
    @name = name
    Thread.current[:name] = name
  end

  private

  def generate_thread_name(thread_index)
    if @name
      "#{@name}-thread:#{thread_index}"
    else
      "#{@name_prefix}-host:#{Socket.gethostname} pid:#{Process.pid} thread:#{thread_index}"
    end
  end

  def thread_name(name)
    # Store the name in thread-local storage && Set the name in the instance variable for compatibility
    Thread.current[:name] = name
    self.name = name
  end

  def stop_signal?
    @stop_signal
  end

  def threaded_work_off
    retry_attempts = 0

    until stop_signal?
      begin
        runtime = Benchmark.realtime do
          @result = work_off(100) # Attempt to process one job
        end

        count = @result[0] + @result[1]

        if count.zero?
          sleep(self.class.sleep_delay) unless stop_signal?
        else
          say sprintf("#{count} jobs processed at %.4f j/s, %d failed", count / runtime, @result.last)
        end
      rescue StandardError => e
        say "Thread #{name} encountered an error: #{e.message}. Restarting thread..."
        retry_attempts += 1
        if retry_attempts >= 5
          say "Thread #{name} has failed #{retry_attempts} times. Exiting to prevent infinite loop."
          break
        end
        sleep(1) # Adding a delay before retrying
        retry
      end
    end

    say 'Stop signal received. Exiting.'
  end

  def trap_signals
    trap('TERM') { initiate_shutdown }
    trap('INT')  { initiate_shutdown }
  end

  def initiate_shutdown
    return if @stop_signal

    Thread.new { say 'Initiating shutdown...' }
    @stop_signal = true

    # Allow threads to finish current jobs
    @threads.each { |t| t.join(30) } # Wait up to 30 seconds for each thread to finish (like monit)
    Thread.new { say 'All threads have finished. Exiting.' }
  end
end
