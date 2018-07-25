module Locket
  class LockWorker
    def initialize(lock_runner)
      @lock_runner = lock_runner
    end

    def acquire_lock_and(&block)
      @lock_runner.start
      loop do
        yield block if @lock_runner.lock_acquired?
      end
    end
  end
end
