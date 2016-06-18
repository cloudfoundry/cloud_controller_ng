require 'jobs/runtime/blobstore_delete.rb'
require 'jobs/v3/buildpack_cache_delete'
require 'actions/package_delete'
require 'actions/task_delete'
require 'actions/droplet_delete'
require 'actions/process_delete'
require 'actions/route_mapping_delete'

module VCAP::CloudController
  class AppDelete
    class InvalidDelete < StandardError; end

    attr_reader :user_guid, :user_email

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_delete')
    end

    def delete(apps)
      apps = Array(apps)

      apps.each do |app|
        raise_if_service_bindings_exist!(app)

        app.db.transaction do
          app.lock!

          delete_subresources(app)

          Repositories::AppEventRepository.new.record_app_delete_request(
            app,
            app.space,
            @user_guid,
            @user_email
          )

          app.destroy
        end
      end
    end

    private

    def delete_subresources(app)
      PackageDelete.new(user_guid, user_email).delete(packages_to_delete(app))
      TaskDelete.new(user_guid, user_email).delete(tasks_to_delete(app))
      DropletDelete.new(user_guid, user_email).delete(droplets_to_delete(app))
      ProcessDelete.new(user_guid, user_email).delete(processes_to_delete(app))
      RouteMappingDelete.new(user_guid, user_email).delete(route_mappings_to_delete(app))
      delete_buildpack_cache(app)
    end

    def route_mappings_to_delete(app)
      RouteMappingModel.where(app_guid: app.guid)
    end

    def delete_buildpack_cache(app)
      delete_job = Jobs::V3::BuildpackCacheDelete.new(app.guid)
      Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
    end

    def packages_to_delete(app_model)
      app_model.packages_dataset
    end

    def droplets_to_delete(app_model)
      app_model.droplets_dataset.
        select(:"#{DropletModel.table_name}__guid",
        :"#{DropletModel.table_name}__id",
        :"#{DropletModel.table_name}__state",
        :"#{DropletModel.table_name}__staging_memory_in_mb",
        :"#{DropletModel.table_name}__app_guid",
        :"#{DropletModel.table_name}__package_guid",
        :"#{DropletModel.table_name}__droplet_hash").all
    end

    def processes_to_delete(app_model)
      app_model.processes_dataset.
        select(:"#{ProcessModel.table_name}__guid",
        :"#{ProcessModel.table_name}__id",
        :"#{ProcessModel.table_name}__app_guid",
        :"#{ProcessModel.table_name}__name",
        :"#{ProcessModel.table_name}__space_id").all
    end

    def tasks_to_delete(app_model)
      app_model.tasks_dataset
    end

    def raise_if_service_bindings_exist!(app)
      unless app.service_bindings_dataset.empty?
        raise InvalidDelete.new('Please delete the service_bindings associations for your apps.')
      end
    end
  end
end
