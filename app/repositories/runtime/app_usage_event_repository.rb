module VCAP::CloudController
  module Repositories
    module Runtime
      class AppUsageEventRepository
        def find(guid)
          AppUsageEvent.find(guid: guid)
        end

        def create_from_app(app, state_name=nil)
          AppUsageEvent.create(state: state_name || app.state,
                               package_state: app.package_state,
                               instance_count: app.instances,
                               memory_in_mb_per_instance: app.memory,
                               app_guid: app.guid,
                               app_name: app.name,
                               org_guid: app.space.organization_guid,
                               space_guid: app.space_guid,
                               space_name: app.space.name,
                               buildpack_guid: app.detected_buildpack_guid,
                               buildpack_name: app.custom_buildpack_url || app.detected_buildpack_name,
                               parent_app_guid: app.app ? app.app.guid : nil,
                               parent_app_name: app.app ? app.app.name : nil,
                               process_type: app.type
          )
        end

        def purge_and_reseed_started_apps!
          AppUsageEvent.dataset.truncate

          column_map = {
              guid: :apps__guid,
              app_guid: :apps__guid,
              app_name: :apps__name,
              state: :apps__state,
              package_state: :apps__package_state,
              instance_count: :apps__instances,
              memory_in_mb_per_instance: :apps__memory,
              space_guid: :spaces__guid,
              space_name: :spaces__name,
              org_guid: :organizations__guid,
              buildpack_guid: :apps__detected_buildpack_guid,
              buildpack_name: :apps__detected_buildpack_name,
              created_at: Sequel.datetime_class.now,
          }

          usage_query = App.join(:spaces, id: :apps__space_id).
              join(:organizations, id: :spaces__organization_id).
              select(*column_map.values).
              where(apps__state: 'STARTED').
              order(:apps__id)

          AppUsageEvent.insert(column_map.keys, usage_query)
        end

        def delete_events_older_than(cutoff_age_in_days)
          old_app_usage_events = AppUsageEvent.dataset.where("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i)
          count_to_delete = old_app_usage_events.count
          old_app_usage_events.delete
          count_to_delete
        end
      end
    end
  end
end
