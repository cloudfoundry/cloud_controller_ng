module VCAP::CloudController
  class TaskModel < Sequel::Model(:tasks)
    TASK_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze
    TASK_STATES = [
      RUNNING_STATE = 'RUNNING'
    ].map(&:freeze).freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel'
    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel'

    def validate
      validates_includes TASK_STATES, :state
      validates_format TASK_NAME_REGEX, :name

      validates_presence :app
      validates_presence :command
      validates_presence :droplet
      validates_presence :name
    end
  end
end
