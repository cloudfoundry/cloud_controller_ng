module VCAP::CloudController
  class TaskLabelModel < Sequel::Model(:task_labels)
    many_to_one :task,
      class: 'VCAP::CloudController::TaskModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
