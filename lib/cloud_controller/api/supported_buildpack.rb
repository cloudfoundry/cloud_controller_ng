# Copyright (c) 2011-2013 Uhuru Software, Inc.

module VCAP::CloudController
  rest_controller :SupportedBuildpack do
    permissions_required do
      full Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute  :name,           String
      attribute  :description,    String
      attribute  :buildpack,      Message::GIT_URL
      attribute  :support_url,    Message::URL
    end

    query_parameters :name, :buildpack

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::SupportedBuildpackNameTaken.new(attributes["name"])
      else
        Errors::SupportedBuildpackInvalid.new(e.errors.full_messages)
      end
    end
  end
end
