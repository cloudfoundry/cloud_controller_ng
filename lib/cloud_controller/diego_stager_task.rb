require 'presenters/message_bus/service_binding_presenter'

module VCAP::CloudController
  class DiegoStagerTask
    class Response
      def initialize(response)
        @response = response
      end

      def detected_buildpack
        @response["detected_buildpack"]
      end

      def error
        @response["error"]
      end

      def timeout
        @response["timeout"]
      end

      def log
        @response["task_log"]
      end
    end

    attr_reader :config
    attr_reader :message_bus

    def initialize(config, message_bus, app, blobstore_url_generator)
      @config = config
      @message_bus = message_bus
      @app = app
      @blobstore_url_generator = blobstore_url_generator
    end

    def task_id
      @task_id ||= VCAP.secure_uuid
    end

    def stage(&completion_callback)

      # The creation of upload handle only guarantees that this cloud controller
      # is disallowed from trying to stage this app again. It does NOT guarantee that a different
      # cloud controller will NOT start staging the app in parallel. Therefore, we need to
      # cache the current task_id here, and later check it was NOT changed by a
      # different cloud controller completing staging request for the same app before
      # this cloud controller completes the staging.
      @app.update(staging_task_id: task_id)

      logger.info("staging.begin", :app_guid => @app.guid)
      subject = "diego.staging.start"
      @message_bus.request(subject, staging_request, {timeout: staging_timeout}) do |bus_response, _|
        logger.info("diego.staging.response", :app_guid => @app.guid, :response => bus_response)

        return unless this_task_is_current_task?

        response = Response.new(bus_response)

        if response.error || response.timeout
          error = response.error || "Request to stage timed out"
          @app.mark_as_failed_to_stage
          Loggregator.emit_error(@app.guid, "Failed to stage application:\n#{error}\n#{response.log}")
          return
        end

        @app.update(detected_buildpack: response.detected_buildpack)

        # Defer potentially expensive operation
        # to avoid executing on reactor thread
        if completion_callback
          EM.defer { completion_callback.call(:started_instances => 0) }
        end
      end
    end

    def staging_request
      {:app_id => app.guid,
       :task_id => task_id,
       :services => app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },
       :memoryMB => app.memory,
       :diskMB => app.disk_quota,
       :fileDescriptors => app.file_descriptors,
       :environment => (app.environment_json || {}).map { |k, v| "#{k}=#{v}" },
       :meta => app.metadata,
       :buildpack_key => app.buildpack.key,
       :stack => app.stack.name,
       # All url generation should go to blobstore_url_generator
       :download_uri => @blobstore_url_generator.app_package_download_url(app),
       :upload_uri => @blobstore_url_generator.droplet_upload_url(app),
       :buildpack_cache_download_uri => @blobstore_url_generator.buildpack_cache_download_url(app),
       :buildpack_cache_upload_uri => @blobstore_url_generator.buildpack_cache_upload_url(app),
       :admin_buildpacks => admin_buildpacks
      }
    end

    private

    def app
      @app
    end

    def this_task_is_current_task?
      app.refresh

      return app.staging_task_id == task_id
    end

    def admin_buildpacks
      Buildpack.list_admin_buildpacks.
          select(&:enabled).
          collect { |buildpack| admin_buildpack_entry(buildpack) }
    end

    def admin_buildpack_entry(buildpack)
      {
          key: buildpack.key,
          url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end

    def service_binding_to_staging_request(service_binding)
      ServiceBindingPresenter.new(service_binding).to_hash
    end

    def staging_timeout
      @config[:staging] && @config[:staging][:max_staging_runtime] || 120
    end

    def logger
      @logger ||= Steno.logger("cc.app_stager")
    end
  end
end
