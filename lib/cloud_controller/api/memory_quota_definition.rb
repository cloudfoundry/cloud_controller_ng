# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :MemoryQuotaDefinition do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute  :name,       String
      attribute  :free_limit, Integer
      attribute  :paid_limit, Integer
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::MemoryQuotaDefinitionNameTaken.new(attributes["name"])
      else
        Errors::MemoryQuotaDefinitionInvalid.new(e.errors.full_messages)
      end
    end
  end
end
