# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Stack do
    disable_default_routes

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::Authenticated
    end

    define_attributes do
      attribute  :name,           String
      attribute  :description,    String
    end

    query_parameters :name

    get path, :enumerate
    get path_guid, :read
  end
end
