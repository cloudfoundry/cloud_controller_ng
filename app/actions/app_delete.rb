require 'jobs/runtime/blobstore_delete.rb'
require 'jobs/v3/buildpack_cache_delete'

module VCAP::CloudController
  class AppDelete
    attr_reader :user_guid, :user_email

    def initialize(user_guid, user_email)
      @user_guid = user_guid
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_delete')
    end

    def delete(apps)
      apps = [apps] unless apps.is_a?(Array)

      apps.each do |app|
        PackageDelete.new.delete(packages_to_delete(app))
        DropletDelete.new.delete(droplets_to_delete(app))
        ProcessDelete.new.delete(processes_to_delete(app))
        delete_buildpack_cache(app)
        app.remove_all_routes

        Repositories::Runtime::AppEventRepository.new.record_app_delete_request(
          app,
          app.space,
          @user_guid,
          @user_email
        )

        app.destroy
      end
    end

    private

    def delete_buildpack_cache(app)
      delete_job = Jobs::V3::BuildpackCacheDelete.new(app.guid)
      Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
    end

    def packages_to_delete(app_model)
      app_model.packages_dataset.select(:"#{PackageModel.table_name}__guid", :"#{PackageModel.table_name}__id").all
    end

    def droplets_to_delete(app_model)
      app_model.droplets_dataset.
        select(:"#{DropletModel.table_name}__guid",
        :"#{DropletModel.table_name}__id",
        :"#{DropletModel.table_name}__droplet_hash").all
    end

    def processes_to_delete(app_model)
      app_model.processes_dataset.
        select(:"#{ProcessModel.table_name}__guid",
        :"#{ProcessModel.table_name}__id",
        :"#{ProcessModel.table_name}__app_guid",
        :"#{ProcessModel.table_name}__name").all
    end
  end
end
