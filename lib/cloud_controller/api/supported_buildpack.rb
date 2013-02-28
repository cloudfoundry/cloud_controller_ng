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

  end
end
