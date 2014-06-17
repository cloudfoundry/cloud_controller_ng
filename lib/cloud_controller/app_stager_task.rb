require 'presenters/message_bus/service_binding_presenter'

module VCAP::CloudController
  class AppStagerTask
    class Response
      def initialize(response)
        @response = response
      end

      def log
        @response["task_log"]
      end

      def streaming_log_url
        @response["task_streaming_log_url"]
      end

      def detected_buildpack
        @response["detected_buildpack"]
      end

      def droplet_hash
        @response["droplet_sha1"]
      end

      def buildpack_key
        @response["buildpack_key"]
      end
    end

    attr_reader :config
    attr_reader :message_bus

    def initialize(config, message_bus, app, dea_pool, stager_pool, blobstore_url_generator)
      @config = config
      @message_bus = message_bus
      @app = app
      @dea_pool = dea_pool
      @stager_pool = stager_pool
      @blobstore_url_generator = blobstore_url_generator
    end

    def task_id
      @task_id ||= VCAP.secure_uuid
    end

    def stage(&completion_callback)
      @stager_id = @stager_pool.find_stager(@app.stack.name, staging_task_memory_mb, staging_task_disk_mb)
      raise Errors::ApiError.new_from_details("StagingError", "no available stagers") unless @stager_id

      subject = "staging.#{@stager_id}.start"
      @multi_message_bus_request = MultiResponseMessageBusRequest.new(@message_bus, subject)

      # Save the current staging task
      @app.update(staging_task_id: task_id)

      # Attempt to stop any in-flight staging for this app
      @message_bus.publish("staging.stop", :app_id => @app.guid)

      @completion_callback = completion_callback

      @dea_pool.reserve_app_memory(@stager_id, staging_task_memory_mb)
      @stager_pool.reserve_app_memory(@stager_id, staging_task_memory_mb)

      logger.info("staging.begin", :app_guid => @app.guid)
      staging_result = EM.schedule_sync do |promise|
        # First response is blocking stage_app.
        @multi_message_bus_request.on_response(staging_timeout) do |response, error|
          logger.info("staging.first-response", :app_guid => @app.guid, :response => response, :error => error)
          handle_first_response(response, error, promise)
        end

        # Second message is received after app staging finished and
        # droplet was uploaded to the CC.
        # Second response does NOT block stage_app
        @multi_message_bus_request.on_response(staging_timeout) do |response, error|
          logger.info("staging.second-response", :app_guid => @app.guid, :response => response, :error => error)
          handle_second_response(response, error)
        end

        @multi_message_bus_request.request(staging_request)
      end

      staging_result
    end

    # We never stage if there is not a start request
    def staging_request
      {
        app_id:                       @app.guid,
        task_id:                      task_id,
        properties:                   staging_task_properties(@app),
        # All url generation should go to blobstore_url_generator
        download_uri:                 @blobstore_url_generator.app_package_download_url(@app),
        upload_uri:                   @blobstore_url_generator.droplet_upload_url(@app),
        buildpack_cache_download_uri: @blobstore_url_generator.buildpack_cache_download_url(@app),
        buildpack_cache_upload_uri:   @blobstore_url_generator.buildpack_cache_upload_url(@app),
        start_message:                start_app_message,
        admin_buildpacks:             admin_buildpacks,
        egress_network_rules:         staging_egress_rules,
      }
    end

    private

    def staging_egress_rules
      staging_security_groups = AppSecurityGroup.where(staging_default: true).all
      EgressNetworkRulesPresenter.new(staging_security_groups).to_array
    end

    def admin_buildpacks
      Buildpack.list_admin_buildpacks.
        select(&:enabled).
        collect { |buildpack| admin_buildpack_entry(buildpack) }.
        select { |entry| entry[:url] }
    end

    def admin_buildpack_entry(buildpack)
      {
        key: buildpack.key,
        url: @blobstore_url_generator.admin_buildpack_download_url(buildpack)
      }
    end

    def start_app_message
      msg = StartAppMessage.new(@app, 0, @config, @blobstore_url_generator)
      msg[:sha1] = nil
      msg
    end

    def handle_first_response(response, error, promise)
      check_staging_error!(response, error)
      ensure_staging_is_current!
      promise.deliver(Response.new(response))
    rescue => e
      Loggregator.emit_error(@app.guid, "exception handling first response #{e.message}")
      logger.error("exception handling first response from stager with id #{@stager_id} response: #{e.inspect}, backtrace: #{e.backtrace.join("\n")}")
      promise.fail(e)
    end

    def handle_second_response(response, error)
      @multi_message_bus_request.ignore_subsequent_responses
      check_staging_error!(response, error)
      ensure_staging_is_current!
      process_response(response)
    rescue => e
      Loggregator.emit_error(@app.guid, "Encountered error: #{e.message}")
      logger.error "Encountered error on stager with id #{@stager_id}: #{e}\n#{e.backtrace.join("\n")}"
    end

    def process_response(response)
      # Defer potentially expensive operation
      # to avoid executing on reactor thread
      EM.defer do
        begin
          staging_completion(Response.new(response))
        rescue => e
          Loggregator.emit_error(@app.guid, "Encountered error: #{e.message}")
          logger.error "Encountered error on stager with id #{@stager_id}: #{e}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    def check_staging_error!(response, error)
      type = error_type(response)
      message = error_message(response)

      if type && message
        @app.mark_as_failed_to_stage(type)
        raise Errors::ApiError.new_from_details(type, message)
      end
    end

    def error_message(response)
      if response.is_a?(String) || response.nil?
        "failed to stage application:\n#{response}"
      elsif response["error_info"]
        response["error_info"]["message"]
      elsif response["error"]
        "failed to stage application:\n#{response["error"]}\n#{response["task_log"]}"
      end
    end

    def error_type(response)
      if response.is_a?(String) || response.nil?
        "StagingError"
      elsif response["error_info"]
        response["error_info"]["type"]
      elsif response["error"]
        "StagingError"
      end
    end

    def ensure_staging_is_current!
      unless staging_is_current?
        raise Errors::ApiError.new_from_details("StagingError", "failed to stage application: another staging request was initiated")
      end
    end

    def staging_is_current?
      # Reload to find other updates of staging task id
      # which means that there was a new staging process initiated
      @app.refresh

      @app.staging_task_id == task_id
    rescue Exception => e
      Loggregator.emit_error(@app.guid, "Exception checking staging status: #{e.message}")
      logger.error("Exception checking staging status: #{e.inspect}\n  #{e.backtrace.join("\n  ")}")
      false
    end

    def staging_completion(stager_response)
      instance_was_started_by_dea = !!stager_response.droplet_hash
      @app.update_detected_buildpack(stager_response.detected_buildpack, stager_response.buildpack_key)
      @dea_pool.mark_app_started(:dea_id => @stager_id, :app_id => @app.guid) if instance_was_started_by_dea

      @completion_callback.call(:started_instances => instance_was_started_by_dea ? 1 : 0) if @completion_callback
    end

    def staging_task_properties(app)
      staging_task_base_properties(app).merge(app.buildpack.staging_message)
    end

    def staging_task_base_properties(app)
      {
        :services    => app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },
        :resources   => {
          :memory => app.memory,
          :disk   => app.disk_quota,
          :fds    => app.file_descriptors
        },

        :environment => (app.environment_json || {}).map {|k,v| "#{k}=#{v}"},
        :meta => app.metadata
      }
    end

    def service_binding_to_staging_request(service_binding)
      ServiceBindingPresenter.new(service_binding).to_hash
    end

    def staging_timeout
      @config[:staging][:timeout_in_seconds]
    end

    def staging_task_disk_mb
      [ @config[:staging][:minimum_staging_disk_mb] || 4096, @app.disk_quota ].max
    end

    def staging_task_memory_mb
      [
        (@config[:staging] && @config[:staging][:minimum_staging_memory_mb] || 1024),
        @app.memory
      ].max
    end

    def logger
      @logger ||= Steno.logger("cc.app_stager")
    end
  end
end
