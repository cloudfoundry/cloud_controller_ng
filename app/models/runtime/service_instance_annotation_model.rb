module VCAP::CloudController
  class ServiceInstanceAnnotationModel < Sequel::Model(:service_instance_annotations)
    many_to_one :service_instance,
                class: 'VCAP::CloudController::ServiceInstance',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
