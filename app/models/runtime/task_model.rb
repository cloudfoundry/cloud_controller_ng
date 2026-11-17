module VCAP::CloudController
  class TaskModel < Sequel::Model(:tasks)
    include Serializer

    TASK_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/
    TASK_STATES = [
      SUCCEEDED_STATE = 'SUCCEEDED'.freeze,
      FAILED_STATE = 'FAILED'.freeze,
      PENDING_STATE = 'PENDING'.freeze,
      RUNNING_STATE = 'RUNNING'.freeze,
      CANCELING_STATE = 'CANCELING'.freeze
    ].map(&:freeze).freeze
    TERMINAL_STATES = [FAILED_STATE, SUCCEEDED_STATE].freeze
    COMMAND_MAX_LENGTH = 4096
    ENV_VAR_MAX_LENGTH = 4096

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel', key: :droplet_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :space, join_table: AppModel.table_name,
                            left_key: :guid, left_primary_key: :app_guid,
                            right_key: :space_guid, right_primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::TaskLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::TaskAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    set_field_as_encrypted :environment_variables, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    def after_update
      super

      return unless column_changed?(:state)

      if running_state?
        create_start_event
      elsif terminal_state?
        create_stop_event_if_needed
      end
    end

    def after_destroy
      super
      create_stop_event unless terminal_state?
    end

    def run_action_user
      return user if user.present?

      if docker?
        docker_run_action_user
      elsif cnb?
        'root' # TODO: Why do CNB tasks default to this user instead of vcap?
      else
        AppModel::DEFAULT_CONTAINER_USER
      end
    end

    def docker?
      !!droplet&.docker?
    end

    def cnb?
      !!droplet&.cnb?
    end

    private

    def permitted_users
      Set.new([AppModel::DEFAULT_CONTAINER_USER]) + Config.config.get(:additional_allowed_process_users)
    end

    def docker_run_action_user
      droplet.docker_user.presence || AppModel::DEFAULT_CONTAINER_USER
    end

    def running_state?
      state == RUNNING_STATE
    end

    def terminal_state?
      TERMINAL_STATES.include? state
    end

    def validate
      validates_includes TASK_STATES, :state
      validates_format TASK_NAME_REGEX, :name

      validates_presence :app
      validates_presence :command
      validates_max_length COMMAND_MAX_LENGTH, :command,
                           message: "must be shorter than #{COMMAND_MAX_LENGTH + 1} characters"
      validate_environment_variables
      validates_presence :droplet if new?
      validates_presence :name
      validate_org_quotas
      validate_space_quotas

      ProcessUserPolicy.new(self, permitted_users).validate
      MinLogRateLimitPolicy.new(self).validate
    end

    def validate_space_quotas
      TaskMaxMemoryPolicy.new(self, space, 'exceeds space memory quota').validate
      TaskMaxInstanceMemoryPolicy.new(self, space, 'exceeds space instance memory quota').validate
      TaskMaxLogRateLimitPolicy.new(self, space, 'exceeds space log rate quota').validate
      new? && MaxAppTasksPolicy.new(self, space, 'quota exceeded').validate
    end

    def validate_org_quotas
      TaskMaxMemoryPolicy.new(self, organization, 'exceeds organization memory quota').validate
      TaskMaxInstanceMemoryPolicy.new(self, organization, 'exceeds organization instance memory quota').validate
      TaskMaxLogRateLimitPolicy.new(self, organization, 'exceeds organization log rate quota').validate
      new? && MaxAppTasksPolicy.new(self, organization, 'quota exceeded').validate
    end

    def validate_environment_variables
      return unless environment_variables

      if environment_variables.to_json.length > ENV_VAR_MAX_LENGTH
        errors.add(:environment_variables,
                   "exceeded the maximum length allowed of #{ENV_VAR_MAX_LENGTH} characters as json")
      end
      VCAP::CloudController::Validators::EnvironmentVariablesValidator.
        validate_each(self, :environment_variables, environment_variables)
    end

    def organization
      space && space.organization
    end

    def create_start_event
      Repositories::AppUsageEventRepository.new.create_from_task(self, 'TASK_STARTED')
    end

    def create_stop_event_if_needed
      app_usage_repo = Repositories::AppUsageEventRepository.new

      start_event = app_usage_repo.find_by_task_and_state(task: self, state: 'TASK_STARTED')
      existing_stop_event = app_usage_repo.find_by_task_and_state(task: self, state: 'TASK_STOPPED')
      return if start_event.nil? || existing_stop_event.present?

      create_stop_event
    end

    def create_stop_event
      Repositories::AppUsageEventRepository.new.create_from_task(self, 'TASK_STOPPED')
    end
  end
end
