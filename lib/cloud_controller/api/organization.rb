# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Organization do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :name, String
      to_many   :users
      to_many   :app_spaces, :exclude_in => :create
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        OrganizationNameTaken.new(attributes["name"])
      else
        OrganizationInvalid.new(e.errors.full_messages)
      end
    end
  end
end
