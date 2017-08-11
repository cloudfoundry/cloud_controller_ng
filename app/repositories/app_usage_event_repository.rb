module VCAP::CloudController
  module Repositories
    class AppUsageEventRepository
      def find(guid)
        AppUsageEvent.find(guid: guid)
      end

      def create_from_process(process, state_name=nil)
        AppUsageEvent.create(
          state:                              state_name || process.state,
          previous_state:                     process.initial_value(:state),
          package_state:                      process.package_state,
          previous_package_state:             'UNKNOWN',
          instance_count:                     process.instances,
          previous_instance_count:            process.initial_value(:instances),
          memory_in_mb_per_instance:          process.memory,
          previous_memory_in_mb_per_instance: process.initial_value(:memory),
          app_guid:                           process.guid,
          app_name:                           process.name,
          org_guid:                           process.space.organization_guid,
          space_guid:                         process.space_guid,
          space_name:                         process.space.name,
          buildpack_guid:                     process.detected_buildpack_guid,
          buildpack_name:                     buildpack_name_for_app(process),
          parent_app_guid:                    process.app.guid,
          parent_app_name:                    process.app.name,
          process_type:                       process.type
        )
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

      def create_from_build(build, state)
        opts = {
          state:                              state,
          previous_state:                     build.initial_value(:state),
          instance_count:                     1,
          previous_instance_count:            1,
          memory_in_mb_per_instance:          BuildModel::STAGING_MEMORY,
          previous_memory_in_mb_per_instance: BuildModel::STAGING_MEMORY,
          org_guid:                           build.space.organization.guid,
          space_guid:                         build.space.guid,
          space_name:                         build.space.name,
          parent_app_guid:                    build.app.guid,
          parent_app_name:                    build.app.name,
          package_guid:                       build.package_guid,
          app_guid:                           '',
          app_name:                           '',
          package_state:                      build.try(:package).try(:state),
          previous_package_state:             build.package ? build.package.initial_value(:state) : nil
        }

        if build.lifecycle_type == Lifecycles::BUILDPACK
          opts[:buildpack_guid] = build.droplet&.buildpack_receipt_buildpack_guid
          opts[:buildpack_name] = CloudController::UrlSecretObfuscator.obfuscate(build.droplet&.buildpack_receipt_buildpack || build.lifecycle_data.buildpacks.first)
        end
        AppUsageEvent.create(opts)
      end

      def purge_and_reseed_started_apps!
        AppUsageEvent.dataset.truncate

        column_map = {
          app_name:                           :parent_app__name,
          guid:                               "#{ProcessModel.table_name}__guid".to_sym,
          app_guid:                           "#{ProcessModel.table_name}__guid".to_sym,
          state:                              "#{ProcessModel.table_name}__state".to_sym,
          previous_state:                     "#{ProcessModel.table_name}__state".to_sym,
          package_state:                      Sequel.case(
            [
              [{ latest_droplet__state: DropletModel::FAILED_STATE }, 'FAILED'],
              [{ latest_droplet__state: DropletModel::STAGED_STATE, latest_droplet__guid: :current_droplet__guid }, 'STAGED'],
              [{ latest_package__state: PackageModel::FAILED_STATE }, 'FAILED'],
            ],
            'PENDING'
          ),
          previous_package_state:             'UNKNOWN',
          instance_count:                     "#{ProcessModel.table_name}__instances".to_sym,
          previous_instance_count:            "#{ProcessModel.table_name}__instances".to_sym,
          memory_in_mb_per_instance:          "#{ProcessModel.table_name}__memory".to_sym,
          previous_memory_in_mb_per_instance: "#{ProcessModel.table_name}__memory".to_sym,
          buildpack_guid:                     :current_droplet__buildpack_receipt_buildpack_guid,
          buildpack_name:                     :current_droplet__buildpack_receipt_buildpack,
          space_guid:                         "#{Space.table_name}__guid".to_sym,
          space_name:                         "#{Space.table_name}__name".to_sym,
          org_guid:                           "#{Organization.table_name}__guid".to_sym,
          created_at:                         Sequel.datetime_class.now,
        }

        latest_package_query = PackageModel.select(:app_guid).select_append { max(id).as(:id) }.group(:app_guid)
        latest_droplet_query = DropletModel.select(:package_guid).select_append { max(id).as(:id) }.group(:package_guid)

        usage_query =
          ProcessModel.
          join(AppModel.table_name, { guid: :app_guid }, table_alias: :parent_app).
          join(Space.table_name, guid: :space_guid).
          join(Organization.table_name, id: :organization_id).
          left_join(DropletModel.table_name, { guid: :parent_app__droplet_guid }, table_alias: :current_droplet).
          left_join(
            PackageModel.table_name,
              {
                guid: PackageModel.select(:guid).join(latest_package_query, { app_guid: :app_guid, id: :id }, table_alias: :b),
                latest_package__app_guid: :parent_app__guid
              },
              table_alias: :latest_package
            ).
          left_join(
            DropletModel.table_name,
              {
                guid: DropletModel.select(:guid).join(latest_droplet_query, { package_guid: :package_guid, id: :id }, table_alias: :b),
                latest_droplet__package_guid: :latest_package__guid
              },
              table_alias: :latest_droplet
            ).
          select(*column_map.values).
          where("#{ProcessModel.table_name}__state".to_sym => 'STARTED').
          order("#{ProcessModel.table_name}__id".to_sym)

        AppUsageEvent.insert(column_map.keys, usage_query)
      end

      def delete_events_older_than(cutoff_age_in_days)
        old_app_usage_events = AppUsageEvent.dataset.where(Sequel.lit("created_at < CURRENT_TIMESTAMP - INTERVAL '?' DAY", cutoff_age_in_days.to_i))
        old_app_usage_events.delete
      end

      private

      def buildpack_name_for_app(app)
        CloudController::UrlSecretObfuscator.obfuscate(app.custom_buildpack_url || app.detected_buildpack_name)
      end
    end
  end
end
