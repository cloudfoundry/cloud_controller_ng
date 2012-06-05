# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Service do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute :label,          String
      attribute :provider,       String
      attribute :url,            Message::HTTPS_URL
      attribute :description,    String
      attribute :version,        String
      attribute :info_url,       Message::URL
      attribute :acls,           {"users" => [String], "wildcards" => [String]}
      attribute :timeout,        Integer
      attribute :active,         Message::Boolean
      to_many   :service_plans
    end

    query_parameters :service_plan_guid

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        ServiceLabelTaken.new("#{attributes["label"]}-#{attributes["provider"]}")
      else
        ServiceInvalid.new(e.errors.full_messages)
      end
    end
  end
end
