module VCAP::CloudController
  class StackUpdate
    class InvalidStack < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.stack_update')
    end

    def update(stack, message)
      stack.db.transaction do
        stack.set(message.to_h)
        stack.save
        MetadataUpdate.update(stack, message)
      end
      @logger.info("Finished updating metadata on stack #{stack.guid}")
      stack
    rescue Sequel::ValidationFailed => e
      raise InvalidStack.new(e.message)
    end
  end
end
