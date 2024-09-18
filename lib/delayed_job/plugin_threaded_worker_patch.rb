module Delayed
  class Plugin
    # Plugin class needs to be initialized with 'Delayed::ThreadedWorker.lifecycle' instead of 'Delayed::Worker.lifecycle'
    def initialize
      self.class.callback_block.call(Delayed::ThreadedWorker.lifecycle) if self.class.callback_block
    end
  end
end
