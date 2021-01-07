module VCAP::CloudController
  class ServiceBindingLabelModel < Sequel::Model(:service_binding_labels)
    many_to_one :service_binding,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
