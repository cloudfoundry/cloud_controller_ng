module VCAP::CloudController
  class ServiceBrokerUpdateRequest < Sequel::Model
    import_attributes :name, :broker_url, :authentication

    set_field_as_encrypted :authentication
  end
end
