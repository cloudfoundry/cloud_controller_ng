module VCAP::CloudController
  class ServiceOfferingAnnotationModel < Sequel::Model(:service_offering_annotations)
    set_primary_key :id
    many_to_one :service,
                class: 'VCAP::CloudController::Service',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
