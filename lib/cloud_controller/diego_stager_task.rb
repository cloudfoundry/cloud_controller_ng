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

    attr_reader :message_bus

    def initialize(staging_timeout, message_bus, app, blobstore_url_generator)
      @staging_timeout = staging_timeout
      @message_bus = message_bus
      @app = app
      @blobstore_url_generator = blobstore_url_generator
    end

    def task_id
      @task_id ||= VCAP.secure_uuid
    end

    def stage(&completion_callback)
      @app.update(staging_task_id: task_id)

      logger.info("staging.begin", :app_guid => @app.guid)

      @message_bus.request("diego.staging.start", staging_request, {timeout: @staging_timeout}) do |bus_response, _|
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
      {
       :app_id => app.guid,
       :task_id => task_id,
       :memory_mb => app.memory,
       :disk_mb => app.disk_quota,
       :file_descriptors => app.file_descriptors,
       :environment => environment,
       :stack => app.stack.name,
       # All url generation should go to blobstore_url_generator
       :app_bits_download_uri => @blobstore_url_generator.app_package_download_url(app),
       :build_artifacts_cache_download_uri => @blobstore_url_generator.buildpack_cache_download_url(@app),
       :build_artifacts_cache_upload_uri => @blobstore_url_generator.buildpack_cache_upload_url(@app),
       :buildpacks => buildpacks
      }
    end

    private

    def environment
      env = []
      env << ["VCAP_APPLICATION", app.vcap_application.to_json]
      env << ["VCAP_SERVICES", app.system_env_json["VCAP_SERVICES"].to_json]
      db_uri = app.database_uri
      env << ["DATABASE_URL", db_uri] if db_uri
      env << ["MEMORY_LIMIT", "#{app.memory}m"]
      app.environment_json.each { |k, v| env << [k, v] }
      env
    end

    def app
      @app
    end

    def this_task_is_current_task?
      app.refresh

      return app.staging_task_id == task_id
    end

    def buildpacks
      Buildpack.list_admin_buildpacks.
          select(&:enabled).
          collect { |buildpack| buildpack_entry(buildpack) }
    end

    def buildpack_entry(buildpack)
      {
          key: buildpack.key,
          url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end

    def service_binding_to_staging_request(service_binding)
      ServiceBindingPresenter.new(service_binding).to_hash
    end

    def logger
      @logger ||= Steno.logger("cc.app_stager")
    end
  end
end
