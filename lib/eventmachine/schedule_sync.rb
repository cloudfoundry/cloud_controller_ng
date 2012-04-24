# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/concurrency"

module EventMachine
  # Runs a block on the reactor thread and blocks the current thread
  # while waiting for the result.  If the block raises an exception,
  # it will re-thrown in the calling thread.
  #
  # @param [Block]  blk  The block to be executed on the reactor thread.
  #
  # @return [Object]  The result of calling blk.
  def self.schedule_sync(&blk)
    promise = VCAP::Concurrency::Promise.new
    EM.schedule do
      begin
        if blk.arity > 0
          blk.call(promise)
        else
          promise.deliver(blk.call)
        end
      rescue Exception => e
        promise.fail(e)
      end
    end

    promise.resolve
  end
end
