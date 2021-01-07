module VCAP::CloudController
  class ServiceKeyLabelModel < Sequel::Model(:service_key_labels)
    many_to_one :service_key,
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
