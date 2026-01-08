require 'repositories/stack_event_repository'

module VCAP::CloudController
  class StackDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(stack)
      stack.db.transaction do
        Repositories::StackEventRepository.new.record_stack_delete(stack, @user_audit_info)
        stack.destroy
      end
    end
  end
end
