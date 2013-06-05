# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServicePlan do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute :name,              String
      attribute :free,              Message::Boolean
      attribute :description,       String
      attribute :extra, String, default: nil
      attribute :unique_id, String, default: nil, exclude_in: [:update]
      to_one    :service
      to_many   :service_instances
      attribute :public, Message::Boolean, default: false
    end

    query_parameters :service_guid, :service_instance_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:service_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::ServicePlanNameTaken.new("#{attributes["service_id"]}-#{attributes["name"]}")
      else
        Errors::ServicePlanInvalid.new(e.errors.full_messages)
      end
    end
  end
end
