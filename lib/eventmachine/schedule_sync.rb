# Copyright (c) 2009-2012 VMware, Inc.

module EventMachine
  # Runs a block on the reactor thread and blocks the current thread
  # while waiting for the result.  If the block raises an exception,
  # it will re-thrown in the calling thread.
  #
  # @param [Block]  blk  The block to be executed on the reactor thread.
  #
  # @return [Object]  The result of calling blk.
  def self.schedule_sync(&blk)
    result = nil
    mutex = Mutex.new
    cv = ConditionVariable.new

    cb = proc do |tmp_result|
      mutex.synchronize do
        result = tmp_result
        cv.signal
      end
    end

    mutex.synchronize do
      EM.schedule do
        begin
          # arguably, we should throw if arity isn't 0 or 1
          if blk.arity > 0
            blk.call(cb)
          else
            cb.call(blk.call)
          end
        rescue Exception => e
          cb.call(e)
        end
      end
      cv.wait(mutex)
    end

    raise result if result.kind_of? Exception
    result
  end
end
