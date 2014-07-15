module VCAP::CloudController
  class OrganizationSummariesController < RestController::ModelController
    path_base "organizations"
    model_class_name :Organization

    get "#{path_guid}/summary", :summary
    def summary(guid)
      org = find_guid_and_validate_access(:read, guid)

      MultiJson.dump(
        :guid => org.guid,
        :name => org.name,
        :status => org.status,
        :spaces => visible_spaces(org).map do |space|
          # when we do the quota work, this and the service counts will be kept
          # as a running total so that we don't have to compute them on the
          # fly.
          space_summary = {
            :app_count => 0,
            :mem_dev_total => 0,
            :mem_prod_total => 0,
          }

          space.apps.each do |app|
            space_summary[:app_count] += 1
            if app.started?
              type = app.production ? :mem_prod_total : :mem_dev_total
              space_summary[type] += app.instances * app.memory
            end
          end

          {
            :guid => space.guid,
            :name => space.name,
            :service_count => space.service_instances_dataset.count,
          }.merge(space_summary)
        end
      )
    end

    private

    def visible_spaces(org)
      org.user_visible_relationship_dataset(:spaces, SecurityContext.current_user, SecurityContext.admin?)
    end
  end
end
