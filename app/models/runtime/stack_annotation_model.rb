module VCAP::CloudController
  class StackAnnotationModel < Sequel::Model(:stack_annotations)
    many_to_one :stack,
      class: 'VCAP::CloudController::Stack',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
