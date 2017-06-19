class WorkPool
  attr_reader :exceptions

  def initialize(size)
    @size = size
    @queue = Queue.new
    @exceptions = []
    lock = Mutex.new
    @threads = Array.new(@size) do
      Thread.new do
        catch(:exit) do
          loop do
            begin
              job, args = @queue.pop
              job.call(*args)
            rescue => e
              lock.synchronize do
                @exceptions << e
              end
            end
          end
        end
      end
    end
  end

  def submit(*args, &block)
    @queue << [block, args]
  end

  def drain
    @size.times do
      submit { throw :exit }
    end

    @threads.map(&:join)
  end
end
