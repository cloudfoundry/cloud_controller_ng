module VCAP::CloudController
  class ServiceInstanceLabelModel < Sequel::Model(:service_instance_labels)
    many_to_one :service_instance,
      class: 'VCAP::CloudController::ServiceInstance',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
