# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :Stats do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def stats(guid, opts = {})
      app = find_guid_and_validate_access(:read, guid)
      stats = DeaClient.find_stats(app, opts)
      [HTTP::OK, Yajl::Encoder.encode(stats)]
    end

    get  "#{path_guid}/stats", :stats
  end
end
