require 'jobs/runtime/blobstore_delete.rb'
require 'jobs/v3/buildpack_cache_delete'
require 'actions/package_delete'
require 'actions/task_delete'
require 'actions/build_delete'
require 'actions/droplet_delete'
require 'actions/deployment_delete'
require 'actions/label_delete'
require 'actions/process_delete'
require 'actions/route_mapping_delete'
require 'actions/staging_cancel'

module VCAP::CloudController
  class AppDelete
    class AsyncBindingDeletionsTriggered < StandardError; end
    class SubResourceError < StandardError
      def initialize(errors)
        @errors = errors
      end

      def underlying_errors
        @errors
      end
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(apps, record_event: true)
      apps.each do |app|
        logger.info("Deleting app: #{app.guid}")

        errs = delete_non_transactional_subresources(app)

        if errs&.any?
          raise SubResourceError.new(errs)
        end

        app.db.transaction do
          app.lock!

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
      DeploymentDelete.new.delete(app.deployments)
      LabelDelete.new.delete(app.labels)
      RouteMappingDelete.new(@user_audit_info).delete(route_mappings_to_delete(app))
      ProcessDelete.new(@user_audit_info).delete(app.processes)
      delete_buildpack_cache(app)
    end

    def delete_non_transactional_subresources(app)
      errors, _ = ServiceBindingDelete.new(@user_audit_info, true).delete(app.service_bindings)
      raise errors.first unless errors.empty?
      async_unbinds = app.service_bindings_dataset.all.select(&:operation_in_progress?)

      if async_unbinds.any?
        async_errors = async_unbinds.map do |binding|
          async_binding_deletion_triggered_error(binding)
        end

        return async_errors
      end
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

    def async_binding_deletion_triggered_error(binding)
      AsyncBindingDeletionsTriggered.new(
        "An operation for the service binding between app #{binding.app.name} and service instance #{binding.service_instance.name} is in progress."
      )
    end
  end
end
