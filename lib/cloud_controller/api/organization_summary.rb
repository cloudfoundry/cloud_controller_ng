# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :OrganizationSummary do
    disable_default_routes
    path_base "organizations"
    model_class_name :Organization

    permissions_required do
      full Permissions::CFAdmin
      read Permissions::OrgManager
      read Permissions::OrgUser
      read Permissions::BillingManager
      read Permissions::Auditor
    end

    def summary(id)
      org = find_id_and_validate_access(:read, id)

      Yajl::Encoder.encode(
        'guid' => org.guid,
        'name' => org.name,
        'spaces' => org.spaces.map do |space|
          # when we do the quota work, this and the service counts will be kept
          # as a running total so that we don't have to compute them on the
          # fly.
          space_summary = {
            'app_count' => 0,
            'mem_dev_total' => 0,
            'mem_prod_total' => 0,
          }

          space.apps.each do |app|
            space_summary['app_count'] += 1
            if app.started?
              type = app.production ? 'mem_prod_total' : 'mem_dev_total'
              space_summary[type] += app.instances * app.memory
            end
          end

          {
            'guid' => space.guid,
            'name' => space.name,
            'service_count' => space.service_instances_dataset.count,
          }.merge(space_summary)
        end
      )
    end

    get "#{path_id}/summary", :summary
  end
end
