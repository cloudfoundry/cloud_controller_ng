# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :AppSummary do
    disable_default_routes
    path_base "apps"
    model_class_name :App

    permissions_required do
      read Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::SpaceManager
      read Permissions::SpaceDeveloper
      read Permissions::SpaceAuditor
    end

    def summary(id)
      app = find_id_and_validate_access(:read, id)
      app_info = {
        :guid => app.guid,
        :name => app.name,
        :routes => app.routes.map(&:as_summary_json),
        :running_instances => app.running_instances,
        :services => app.service_instances.map(&:as_summary_json),
        :available_domains => app.space.domains.map(&:as_summary_json)
      }.merge(app.to_hash)

      Yajl::Encoder.encode(app_info)
    end

    private

    get "#{path_id}/summary", :summary
  end
end
