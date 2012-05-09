# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceInstance do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name,             String
      to_one    :app_space
      to_one    :service_plan
      to_many   :service_bindings
      attribute :credentials,      Hash
      attribute :vendor_data,      String, :default => "" # FIXME: notation for access override here
    end

    def self.translate_validation_exception(e, attributes)
      app_space_and_name_errors = e.errors.on([:app_space_id, :name])
      if app_space_and_name_errors && app_space_and_name_errors.include?(:unique)
        ServiceInstanceNameTaken.new(attributes["name"])
      else
        ServiceInstanceInvalid.new(e.errors.full_messages)
      end
    end
  end
end
