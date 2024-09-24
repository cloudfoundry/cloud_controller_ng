module Delayed
  class Plugin
    def initialize
      # Plugin class needs to be initialized with 'Delayed::ThreadedWorker.lifecycle' instead of 'Delayed::Worker.lifecycle'
      if Delayed::ThreadedWorker.require_plugin_monkey_patch?
        self.class.callback_block.call(Delayed::ThreadedWorker.lifecycle) if self.class.callback_block
      elsif self.class.callback_block
        self.class.callback_block.call(Delayed::Worker.lifecycle)
      end
    end
  end
end
