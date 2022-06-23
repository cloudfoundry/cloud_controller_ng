module VCAP::CloudController
  module ServiceOperationMixin
    INITIAL = 'initial'.freeze
    IN_PROGRESS = 'in progress'.freeze
    SUCCEEDED = 'succeeded'.freeze
    FAILED = 'failed'.freeze

    def operation_in_progress?
      last_operation? && [INITIAL, IN_PROGRESS].include?(last_operation.state)
    end

    def terminal_state?
      !last_operation? || [SUCCEEDED, FAILED].include?(last_operation.state)
    end

    def create_initial?
      create? && initial?
    end

    def create_in_progress?
      create? && (initial? || in_progress?)
    end

    def create_succeeded?
      !last_operation? || (create? && succeeded?)
    end

    def create_failed?
      create? && failed?
    end

    def update_in_progress?
      last_operation_is_update? && in_progress?
    end

    def update_succeeded?
      last_operation_is_update? && succeeded?
    end

    def update_failed?
      last_operation_is_update? && failed?
    end

    def delete_in_progress?
      delete? && in_progress?
    end

    def delete_failed?
      delete? && failed?
    end

    def last_operation_is_update?
      last_operation&.type == 'update'
    end

    private

    def last_operation?
      !last_operation.nil?
    end

    def create?
      last_operation&.type == 'create'
    end

    def delete?
      last_operation&.type == 'delete'
    end

    def initial?
      last_operation&.state == INITIAL
    end

    def in_progress?
      last_operation&.state == IN_PROGRESS
    end

    def succeeded?
      last_operation&.state == SUCCEEDED
    end

    def failed?
      last_operation&.state == FAILED
    end
  end
end
