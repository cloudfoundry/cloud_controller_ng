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

    get path, :enumerate
    get path_id, :read
  end
end
