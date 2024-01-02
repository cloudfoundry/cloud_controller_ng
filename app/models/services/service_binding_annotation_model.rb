module VCAP::CloudController
  class ServiceBindingAnnotationModel < Sequel::Model(:service_binding_annotations)
    set_primary_key :id
    many_to_one :service_binding,
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
