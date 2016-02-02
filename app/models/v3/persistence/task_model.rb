module VCAP::CloudController
  class TaskModel < Sequel::Model(:tasks)
    include Serializer
    TASK_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze
    TASK_STATES = [
      SUCCEEDED_STATE = 'SUCCEEDED',
      FAILED_STATE = 'FAILED',
      RUNNING_STATE = 'RUNNING'
    ].map(&:freeze).freeze
    COMMAND_MAX_LENGTH = 4096.freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel'
    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel'
    one_through_one :space, join_table: AppModel.table_name,
                            left_key: :guid, left_primary_key: :app_guid,
                            right_key: :space_guid, right_primary_key: :guid
    serializes_via_json :environment_variables

    def validate
      validates_includes TASK_STATES, :state
      validates_format TASK_NAME_REGEX, :name

      validates_presence :app
      validates_presence :command
      validates_max_length COMMAND_MAX_LENGTH, :command,
        message: "must be shorter than #{COMMAND_MAX_LENGTH + 1} characters"
      validate_environment_variables
      validates_presence :droplet
      validates_presence :name
      validate_space_quotas
    end

    def validate_space_quotas
      return unless space && space.space_quota_definition

      unless space.has_remaining_memory(memory_in_mb)
        errors.add(:memory_in_mb, 'space memory limit')
      end

      instance_memory_limit = space.instance_memory_limit
      if instance_memory_limit != QuotaDefinition::UNLIMITED && memory_in_mb > instance_memory_limit
        errors.add(:memory_in_mb, 'space instance memory limit')
      end
    end

    def validate_environment_variables
      return unless environment_variables
      validator = VCAP::CloudController::Validators::EnvironmentVariablesValidator.new({ attributes: [:environment_variables] })
      validator.validate_each(self, :environment_variables, environment_variables)
    end
  end
end
