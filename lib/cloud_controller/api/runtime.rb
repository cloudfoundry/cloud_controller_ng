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

      # version was really a v1 concept, but the yeti tests expect it
      attribute :version,        String, :exclude_in => [:create, :update]
      to_many   :apps,           :default => []
    end

    query_parameters :name, :app_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::RuntimeNameTaken.new(attributes["name"])
      else
        Errors::RuntimeInvalid.new(e.errors.full_messages)
      end
    end
  end
end
