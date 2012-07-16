# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceBinding do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      full Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    define_attributes do
      attribute :credentials,          Hash
      attribute :binding_options,      Hash, :default => {}
      attribute :vendor_data,          Hash, :default => {}
      to_one    :app
      to_one    :service_instance
    end

    query_parameters :app_guid, :service_instance_guid

    def self.translate_validation_exception(e, attributes)
      unique_errors = e.errors.on([:app_id, :service_instance_id])
      if unique_errors && unique_errors.include?(:unique)
        ServiceBindingAppServiceTaken.new(
          "#{attributes["app_guid"]} #{attributes["service_instance_guid"]}")
      else
        ServiceBindingInvalid.new(e.errors.full_messages)
      end
    end
  end
end
