# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :QuotaDefinition do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute  :name,                       String
      attribute  :non_basic_services_allowed, Message::Boolean
      attribute  :total_services,             Integer
      attribute  :memory_limit,               Integer
      attribute  :free_rds,                   Message::Boolean, :default => false
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::QuotaDefinitionNameTaken.new(attributes["name"])
      else
        Errors::QuotaDefinitionInvalid.new(e.errors.full_messages)
      end
    end
  end
end
