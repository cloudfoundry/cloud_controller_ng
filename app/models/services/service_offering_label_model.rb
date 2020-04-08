module VCAP::CloudController
  class ServiceOfferingLabelModel < Sequel::Model(:service_offering_labels)
    many_to_one :service,
      class: 'VCAP::CloudController::Service',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
