module VCAP::CloudController
  module ServiceCredentialBindingMixin
    def terminal_state?
      !last_operation || (%w(succeeded failed).include? last_operation.state)
    end

    def operation_in_progress?
      !!last_operation && last_operation.state == 'in progress'
    end

    def create_succeeded?
      return true unless last_operation
      return true if last_operation&.type == 'create' && last_operation.state == 'succeeded'

      false
    end

    def create_in_progress?
      return true if last_operation&.type == 'create' && last_operation.state == 'in progress'

      false
    end

    def create_failed?
      return true if last_operation&.type == 'create' && last_operation.state == 'failed'

      false
    end

    def delete_failed?
      return true if last_operation&.type == 'delete' && last_operation.state == 'failed'

      false
    end

    def delete_in_progress?
      return true if last_operation&.type == 'delete' && last_operation.state == 'in progress'

      false
    end
  end
end
