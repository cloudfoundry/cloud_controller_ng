module Locket
  class LockWorker
    def initialize(client)
      @client = client
    end

    def acquire_lock_and_repeatedly_call(owner:, key:, &block)
      @client.start(owner: owner, key: key)
      loop do
        if @client.lock_acquired?
          yield block
        else
          sleep 1
        end
      end
    end
  end
end
