class WorkPool
  attr_reader :exceptions, :threads

  def initialize(size, store_exceptions: false)
    @size = size
    @store_exceptions = store_exceptions

    @queue = Queue.new
    @exceptions = []
    @lock = Mutex.new
    @threads = Array.new(@size) do
      create_workpool_thread
    end
  end

  def submit(*args, &block)
    @queue << [block, args]
  end

  def replenish
    @threads.each_with_index do |thread, index|
      @threads[index] = create_workpool_thread unless thread.status
    end
  end

  def drain
    @size.times do
      submit { throw :exit }
    end

    @threads.map(&:join)
  end

  private

  def create_workpool_thread
    Thread.new do
      catch(:exit) do
        loop do
          job, args = @queue.pop
          job.call(*args)
        rescue => e
          next unless @store_exceptions

          @lock.synchronize do
            @exceptions << e
          end
        end
      end
    end
  end
end
