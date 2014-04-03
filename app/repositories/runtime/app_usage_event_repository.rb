module VCAP::CloudController
  module Repositories
    module Runtime
      class AppUsageEventRepository
        def find(guid)
          AppUsageEvent.find(guid: guid)
        end

        def purge_and_reseed_started_apps!
          AppUsageEvent.db[:app_usage_events].truncate
          usage_query = App.join(:spaces, id: :apps__space_id).
              join(:organizations, id: :spaces__organization_id).
              select(:apps__guid, :apps__guid, :apps__name, :apps__state, :apps__instances, :apps__memory, :spaces__guid, :spaces__name, :organizations__guid, Sequel.datetime_class.now).
              where(:apps__state => 'STARTED').
              order(:apps__id)
          AppUsageEvent.insert([:guid, :app_guid, :app_name, :state, :instance_count, :memory_in_mb_per_instance, :space_guid, :space_name, :org_guid, :created_at], usage_query)
        end

        def create_from_app(app)
          AppUsageEvent.create(state: app.state,
                               instance_count: app.instances,
                               memory_in_mb_per_instance: app.memory,
                               app_guid: app.guid,
                               app_name: app.name,
                               org_guid: app.space.organization_guid,
                               space_guid: app.space_guid,
                               space_name: app.space.name,
                               buildpack_name: app.custom_buildpack_url || app.buildpack_name,
                               buildpack_guid: app.buildpack_guid,
          )
        end

        def delete_events_create_before(cutoff_time)
          old_app_usage_events = AppUsageEvent.dataset.where("created_at < ?", cutoff_time)
          count_to_delete = old_app_usage_events.count
          old_app_usage_events.delete
          count_to_delete
        end
      end
    end
  end
end
