module VCAP::CloudController
  module Repositories
    class AppUsageEventRepository
      def find(guid)
        AppUsageEvent.find(guid: guid)
      end

      def create_from_app(app, state_name=nil)
        AppUsageEvent.create(
          state:                              state_name || app.state,
          previous_state:                     app.initial_value(:state),
          package_state:                      app.package_state,
          previous_package_state:             app.initial_value(:package_state),
          instance_count:                     app.instances,
          previous_instance_count:            app.initial_value(:instances),
          memory_in_mb_per_instance:          app.memory,
          previous_memory_in_mb_per_instance: app.initial_value(:memory),
          app_guid:                           app.guid,
          app_name:                           app.name,
          org_guid:                           app.space.organization_guid,
          space_guid:                         app.space_guid,
          space_name:                         app.space.name,
          buildpack_guid:                     buildpack_guid_for_app(app),
          buildpack_name:                     buildpack_name_for_app(app),
          parent_app_guid:                    app.app.guid,
          parent_app_name:                    app.app.name,
          process_type:                       app.type
        )
      end

      def buildpack_name_for_app(app)
        if !app.droplet.is_a?(DropletModel)
          app.custom_buildpack_url || app.detected_buildpack_name
        else
          process = app
          droplet = process.app.droplet
          return nil unless droplet.present?
          return droplet.buildpack_receipt_buildpack if droplet.buildpack_receipt_buildpack.present?

          if droplet.lifecycle_data && droplet.lifecycle_data.class::LIFECYCLE_TYPE != 'docker'
            droplet.lifecycle_data.buildpack
          end
        end
      end

      def buildpack_guid_for_app(app)
        return app.app.droplet.buildpack_receipt_buildpack_guid if app.droplet.is_a?(DropletModel)
        app.detected_buildpack_guid
      end

      def create_from_task(task, state)
        AppUsageEvent.create(
          state:                              state,
          previous_state:                     task.initial_value(:state),
          package_state:                      'STAGED',
          previous_package_state:             'STAGED',
          instance_count:                     1,
          previous_instance_count:            1,
          memory_in_mb_per_instance:          task.memory_in_mb,
          previous_memory_in_mb_per_instance: task.initial_value(:memory_in_mb),
          app_guid:                           '',
          app_name:                           '',
          org_guid:                           task.space.organization.guid,
          space_guid:                         task.space.guid,
          space_name:                         task.space.name,
          buildpack_guid:                     nil,
          buildpack_name:                     nil,
          parent_app_guid:                    task.app.guid,
          parent_app_name:                    task.app.name,
          process_type:                       nil,
          task_guid:                          task.guid,
          task_name:                          task.name,
        )
      end

      def create_from_droplet(droplet, state)
        opts = {
          state:                              state,
          previous_state:                     droplet.initial_value(:state),
          instance_count:                     1,
          previous_instance_count:            1,
          memory_in_mb_per_instance:          droplet.staging_memory_in_mb,
          previous_memory_in_mb_per_instance: droplet.initial_value(:staging_memory_in_mb),
          org_guid:                           droplet.space.organization.guid,
          space_guid:                         droplet.space.guid,
          space_name:                         droplet.space.name,
          parent_app_guid:                    droplet.app.guid,
          parent_app_name:                    droplet.app.name,
          package_guid:                       droplet.package_guid,
          app_guid:                           '',
          app_name:                           '',
          package_state:                      droplet.try(:package).try(:state),
          previous_package_state:             droplet.package ? droplet.package.initial_value(:state) : nil
        }

        if droplet.lifecycle_type == Lifecycles::BUILDPACK
          opts[:buildpack_guid] = droplet.buildpack_receipt_buildpack_guid
          opts[:buildpack_name] = droplet.buildpack_receipt_buildpack || droplet.lifecycle_data.buildpack
        end

        AppUsageEvent.create(opts)
      end

      def purge_and_reseed_started_apps!
        AppUsageEvent.dataset.truncate

        column_map = {
          app_name:                           :apps__name,
          guid:                               :processes__guid,
          app_guid:                           :processes__guid,
          state:                              :processes__state,
          previous_state:                     :processes__state,
          package_state:                      :processes__package_state,
          previous_package_state:             :processes__package_state,
          instance_count:                     :processes__instances,
          previous_instance_count:            :processes__instances,
          memory_in_mb_per_instance:          :processes__memory,
          previous_memory_in_mb_per_instance: :processes__memory,
          buildpack_guid:                     :processes__detected_buildpack_guid,
          buildpack_name:                     :processes__detected_buildpack_name,
          space_guid:                         :spaces__guid,
          space_name:                         :spaces__name,
          org_guid:                           :organizations__guid,
          created_at:                         Sequel.datetime_class.now,
        }

        usage_query = App.join(AppModel.table_name.to_sym, guid: :app_guid).
                      join(Space.table_name.to_sym, guid: :space_guid).
                      join(Organization.table_name.to_sym, id: :organization_id).
                      select(*column_map.values).
                      where(processes__state: 'STARTED').
                      order(:processes__id)

        AppUsageEvent.insert(column_map.keys, usage_query)
      end

      def delete_events_older_than(cutoff_age_in_days)
        old_app_usage_events = AppUsageEvent.dataset.where("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i)
        old_app_usage_events.delete
      end
    end
  end
end
