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
        stack_updates = {}
        stack_updates[:state] = message.state if message.requested?(:state)
        stack_updates[:state_reason] = message.state_reason if message.requested?(:state_reason)
        stack.update(stack_updates) if stack_updates.any?

        MetadataUpdate.update(stack, message)
        Repositories::StackEventRepository.new.record_stack_update(stack, @user_audit_info, message.audit_hash)
      end
      @logger.info("Finished updating stack #{stack.guid}")

      stack
    rescue Sequel::ValidationFailed => e
      raise InvalidStack.new(e.message)
    end
  end
end
