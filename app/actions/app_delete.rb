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

    def delete(apps, record_event: true)
      apps = Array(apps)

      apps.each do |app|
        app.db.transaction do
          app.lock!

          delete_subresources(app)

          record_audit_event(app) if record_event

          app.destroy
        end
      end
    end

    def delete_without_event(apps)
      delete(apps, record_event: false)
    end

    private

    def record_audit_event(app)
      Repositories::AppEventRepository.new.record_app_delete_request(
        app,
        app.space,
        @user_guid,
        @user_email
      )
    end

    def delete_subresources(app)
      PackageDelete.new(user_guid, user_email).delete(app.packages)
      TaskDelete.new(user_guid, user_email).delete(app.tasks)
      DropletDelete.new(user_guid, user_email, stagers).delete(app.droplets)
      ProcessDelete.new(user_guid, user_email).delete(app.processes)
      RouteMappingDelete.new(user_guid, user_email).delete(route_mappings_to_delete(app))
      ServiceBindingDelete.new(user_guid, user_email).delete(app.service_bindings)
      delete_buildpack_cache(app)
    end

    def stagers
      CloudController::DependencyLocator.instance.stagers
    end

    def route_mappings_to_delete(app)
      RouteMappingModel.where(app_guid: app.guid)
    end

    def delete_buildpack_cache(app)
      delete_job = Jobs::V3::BuildpackCacheDelete.new(app.guid)
      Jobs::Enqueuer.new(delete_job, queue: 'cc-generic').enqueue
    end
  end
end
