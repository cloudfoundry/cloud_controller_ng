require 'jobs/runtime/blobstore_delete.rb'
require 'jobs/v3/buildpack_cache_delete'
require 'actions/package_delete'
require 'actions/task_delete'
require 'actions/build_delete'
require 'actions/droplet_delete'
require 'actions/process_delete'
require 'actions/route_mapping_delete'
require 'actions/staging_cancel'

module VCAP::CloudController
  class AppDelete
    class InvalidDelete < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(apps, record_event: true)
      apps.each do |app|
        app.db.transaction do
          app.lock!
          logger.info("Deleting app: #{app.guid}")

          delete_subresources(app)

          record_audit_event(app) if record_event

          app.destroy
        end
        logger.info("Deleted app: #{app.guid}")
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
        @user_audit_info,
      )
    end

    def delete_subresources(app)
      PackageDelete.new(@user_audit_info).delete(app.packages)
      TaskDelete.new(@user_audit_info).delete(app.tasks)
      BuildDelete.new(StagingCancel.new(stagers)).delete(app.builds)
      DropletDelete.new(@user_audit_info).delete(app.droplets)
      ProcessDelete.new(@user_audit_info).delete(app.processes)
      RouteMappingDelete.new(@user_audit_info).delete(route_mappings_to_delete(app))
      errors = ServiceBindingDelete.new(@user_audit_info).delete(app.service_bindings)
      raise errors.first unless errors.empty?
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

    def logger
      @logger ||= Steno.logger('cc.action.app_delete')
    end
  end
end
