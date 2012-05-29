# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Runtime do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute :name,           String
      attribute :description,    String
      to_many   :apps,           :default => []
    end

    query_parameters :name, :app_id

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        RuntimeNameTaken.new(attributes["name"])
      else
        RuntimeInvalid.new(e.errors.full_messages)
      end
    end
  end
end
