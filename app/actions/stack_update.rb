require 'repositories/stack_event_repository'

module VCAP::CloudController
  class StackUpdate
    class InvalidStack < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.stack_update')
    end

    def update(stack, message)
      stack.db.transaction do
        stack.update(state: message.state) if message.requested?(:state)
        MetadataUpdate.update(stack, message)
        Repositories::StackEventRepository.new.record_stack_update(stack, @user_audit_info, message.audit_hash)
      end
      @logger.info("Finished updating metadata on stack #{stack.guid}")

      stack
    rescue Sequel::ValidationFailed => e
      raise InvalidStack.new(e.message)
    end
  end
end
