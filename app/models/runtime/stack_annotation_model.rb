module VCAP::CloudController
  class StackAnnotationModel < Sequel::Model(:stack_annotations)
    set_primary_key :id
    many_to_one :stack,
                class: 'VCAP::CloudController::Stack',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
