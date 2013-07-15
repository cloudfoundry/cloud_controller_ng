require 'cloud_controller/presenters/service_binding_presenter'

module VCAP::CloudController
  class AppStagerTask
    class Response
      def initialize(response)
        @response = response
      end

      def log
        @response[:task_log]
      end

      def streaming_log_url
        @response[:task_streaming_log_url]
      end

      def detected_buildpack
        @response[:detected_buildpack]
      end
    end

    attr_reader :config
    attr_reader :message_bus

    def initialize(config, message_bus, app, stager_pool)
      @config = config
      @message_bus = message_bus
      @app = app
      @stager_pool = stager_pool
    end

    def task_id
      @task_id ||= VCAP.secure_uuid
    end

    def stage(&completion_callback)
      stager_id = @stager_pool.find_stager(@app.stack.name, 1024)
      raise Errors::StagingError, "no available stagers" unless stager_id

      subject = "staging.#{stager_id}.start"
      @multi_message_bus_request = MultiResponseMessageBusRequest.new(@message_bus, subject)
      # The creation of upload handle only guarantees that this cloud controller
      # is disallowed from trying to stage this app again. It does NOT guarantee that a different
      # cloud controller will NOT start staging the app in parallel. Therefore, we need to
      # cache the current droplet hash here, and later check it was NOT changed by a
      # different cloud controller completing staging request for the same app before
      # this cloud controller completes the staging.
      @current_droplet_hash = @app.droplet_hash

      @app.staging_task_id = task_id
      @app.save

      @message_bus.publish("staging.stop", :app_id => @app.guid)

      @upload_handle = Staging.create_handle(@app.guid)
      @completion_callback = completion_callback

      staging_result = EM.schedule_sync do |promise|
        # First response is blocking stage_app.
        @multi_message_bus_request.on_response(staging_timeout) do |response, error|
          handle_first_response(response, error, promise)
        end

        # Second message is received after app staging finished and
        # droplet was uploaded to the CC.
        # Second response does NOT block stage_app
        @multi_message_bus_request.on_response(staging_timeout) do |response, error|
          handle_second_response(response, error)
        end

        @multi_message_bus_request.request(staging_request)
      end

      staging_result
    end

    def staging_request
      { :app_id => @app.guid,
        :task_id => task_id,
        :properties => staging_task_properties(@app),
        :download_uri => Staging.app_uri(@app),
        :upload_uri => Staging.droplet_upload_uri(@app),
        :buildpack_cache_download_uri => Staging.buildpack_cache_download_uri(@app),
        :buildpack_cache_upload_uri => Staging.buildpack_cache_upload_uri(@app)
      }
    end

    private

    def handle_first_response(response, error, promise)
      check_staging_error!(response, error)
      ensure_staging_is_current!
      promise.deliver(Response.new(response))
    rescue => e
      logger.error("exception handling first response #{e.inspect}, backtrace: #{e.backtrace.join("\n")}")
      destroy_upload_handle if staging_is_current?
      promise.fail(e)
    end


    def handle_second_response(response, error)
      @multi_message_bus_request.ignore_subsequent_responses
      check_staging_error!(response, error)
      ensure_staging_is_current!
      process_response(response)
    rescue => e
      destroy_upload_handle if staging_is_current?
      logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
    end

    def process_response(response)
      # Defer potentially expensive operation
      # to avoid executing on reactor thread
      EM.defer do
        begin
          staging_completion(Response.new(response))
          trigger_completion_callback
        rescue => e
          logger.error "Encountered error: #{e}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    def check_staging_error!(response, error)
      if (msg = error_message(response))
        @app.mark_as_failed_to_stage
        raise Errors::StagingError, msg
      end
    end

    def error_message(response)
      if response.is_a?(String) || response.nil?
        "failed to stage application:\n#{response}"
      elsif response[:error]
        "failed to stage application:\n#{response[:error]}\n#{response[:task_log]}"
      end
    end

    def ensure_staging_is_current!
      unless staging_is_current?
        raise Errors::StagingError, "failed to stage application: another staging request was initiated"
      end
    end

    def staging_is_current?
      # Reload to find other updates of staging task id
      # which means that there was a new staging process initiated
      @app.refresh

      @app.staging_task_id == task_id
    rescue Exception => e
      logger.error("Exception checking staging status: #{e.inspect}\n  #{e.backtrace.join("\n  ")}")
      false
    end

    def staging_completion(stager_response)
      @app.droplet_hash = Digest::SHA1.file(@upload_handle.upload_path).hexdigest
      @app.detected_buildpack = stager_response.detected_buildpack

      Staging.store_droplet(@app, @upload_handle.upload_path)

      if (buildpack_cache = @upload_handle.buildpack_cache_upload_path)
        Staging.store_buildpack_cache(@app, buildpack_cache)
      end

      @app.save
    ensure
      destroy_upload_handle
    end

    def trigger_completion_callback
      @completion_callback.call if @completion_callback
    end

    def destroy_upload_handle
      Staging.destroy_handle(@upload_handle)
    end

    def staging_task_properties(app)
      {
        :services    => app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },

        :buildpack => app.buildpack,

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
      @config[:staging] && @config[:staging][:max_staging_runtime] || 120
    end

    def logger
      @logger ||= Steno.logger("cc.app_stager")
    end
  end
end
