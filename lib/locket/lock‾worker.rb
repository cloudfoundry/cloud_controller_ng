module Locket
  class LockWorker
    def initialize(lock_runner)
      @lock_runner = lock_runner
    end

    def acquire_lock_and_repeatedly_call(&block)
      @lock_runner.start
      loop do
        if @lock_runner.lock_acquired?
          yield block
        else
          sleep 1
        end
      end
    end
  end
end
