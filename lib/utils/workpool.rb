class WorkPool
  def initialize(size)
    @size = size
    @queue = Queue.new
    @threads = Array.new(@size) do
      Thread.new do
        catch(:exit) do
          loop do
            job, args = @queue.pop
            job.call(*args)
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
