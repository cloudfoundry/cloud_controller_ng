module VCAP::CloudController
  class TaskAnnotationModel < Sequel::Model(:task_annotations)
    many_to_one :task,
      class: 'VCAP::CloudController::TaskModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
