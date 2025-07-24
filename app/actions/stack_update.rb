module VCAP::CloudController
  class StackUpdate
    class InvalidStack < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.stack_update')
    end

    def update(stack, message)
      stack.db.transaction do
        # Update stack attributes (excluding metadata which is handled separately)
        stack_attributes = {}
        %i[deprecated_at locked_at disabled_at].each do |attr|
          stack_attributes[attr] = message.public_send(attr) if message.requested?(attr)
        end
        stack.set(stack_attributes) if stack_attributes.any?
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
