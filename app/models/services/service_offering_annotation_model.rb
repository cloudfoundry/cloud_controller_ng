module VCAP::CloudController
  class ServiceOfferingAnnotationModel < Sequel::Model(:service_offering_annotations)
    many_to_one :service,
                class: 'VCAP::CloudController::Service',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
