# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Framework do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute  :name,           String
      attribute  :description,    String
      to_many    :apps
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        FrameworkNameTaken.new(attributes[:name])
      else
        FrameworkInvalid.new(e.errors.full_messages)
      end
    end
  end
end
