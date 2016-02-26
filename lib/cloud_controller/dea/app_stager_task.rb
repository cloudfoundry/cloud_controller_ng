require 'presenters/message_bus/service_binding_presenter'

module VCAP::CloudController
  module Dea
    class AppStagerTask
      STAGING_ALREADY_FAILURE_MSG = 'failed to stage application: staging had already been marked as failed, this could mean that staging took too long'.freeze

      attr_reader :config
      attr_reader :message_bus

      def initialize(config, message_bus, app, dea_pool, blobstore_url_generator)
        @config = config
        @message_bus = message_bus
        @app = app
        @dea_pool = dea_pool
        @blobstore_url_generator = blobstore_url_generator
      end

      def task_id
        @task_id ||= VCAP.secure_uuid
      end

      def stage(&completion_callback)
        @stager_id = @dea_pool.find_stager(@app.stack.name, staging_task_memory_mb, staging_task_disk_mb)
        raise Errors::ApiError.new_from_details('StagingError', 'no available stagers') unless @stager_id

        subject = "staging.#{@stager_id}.start"
        @multi_message_bus_request = MultiResponseMessageBusRequest.new(@message_bus, subject)

        # Save the current staging task
        @app.update(package_state: 'PENDING', staging_task_id: task_id)

        # Attempt to stop any in-flight staging for this app
        @message_bus.publish('staging.stop', app_id: @app.guid)

        @completion_callback = completion_callback

        @dea_pool.reserve_app_memory(@stager_id, staging_task_memory_mb)

        logger.info('staging.begin', app_guid: @app.guid)
        staging_msg = staging_request

        staging_result = EM.schedule_sync do |promise|
          # First response is blocking stage_app.
          @multi_message_bus_request.on_response(staging_timeout) do |response, error|
            logger.info('staging.first-response', app_guid: @app.guid, response: response, error: error)
            handle_first_response(response, error, promise)
          end

          # Second message is received after app staging finished and
          # droplet was uploaded to the CC.
          # Second response does NOT block stage_app
          @multi_message_bus_request.on_response(staging_timeout) do |response, error|
            logger.info('staging.second-response', app_guid: @app.guid, response: response, error: error)
            handle_second_response(response, error)
          end

          @multi_message_bus_request.request(staging_msg)
        end

        staging_result
      end

      # We never stage if there is not a start request
      def staging_request
        StagingMessage.new(@config, @blobstore_url_generator).staging_request(@app, task_id)
      end

      private

      def handle_first_response(response, error, promise)
        ensure_staging_is_current!
        check_staging_error!(response, error)
        promise.deliver(StagingResponse.new(response))
      rescue => e
        Loggregator.emit_error(@app.guid, "exception handling first response #{e.message}")
        logger.error("exception handling first response from stager with id #{@stager_id} response: #{e.inspect}, backtrace: #{e.backtrace.join("\n")}")
        promise.fail(e)
      end

      def handle_second_response(response, error)
        @multi_message_bus_request.ignore_subsequent_responses
        ensure_staging_is_current!
        check_staging_error!(response, error)
        process_response(response)
      rescue => e
        Loggregator.emit_error(@app.guid, "encountered error: #{e.message}")
        logger.error "Encountered error on stager with id #{@stager_id}: #{e}\n#{e.backtrace.join("\n")}"
      end

      def process_response(response)
        # Defer potentially expensive operation
        # to avoid executing on reactor thread
        EM.defer do
          begin
            staging_completion(StagingResponse.new(response))
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
        elsif response['error_info']
          response['error_info']['message']
        elsif response['error']
          "failed to stage application:\n#{response['error']}\n#{response['task_log']}"
        end
      end

      def error_type(response)
        if response.is_a?(String) || response.nil?
          'StagingError'
        elsif response['error_info']
          response['error_info']['type']
        elsif response['error']
          'StagingError'
        end
      end

      def ensure_staging_is_current!
        begin
          # Reload to find other updates of staging task id
          # which means that there was a new staging process initiated
          @app.refresh
        rescue => e
          Loggregator.emit_error(@app.guid, "Exception checking staging status: #{e.message}")
          logger.error("Exception checking staging status: #{e.inspect}\n  #{e.backtrace.join("\n  ")}")
          raise Errors::ApiError.new_from_details('StagingError', "failed to stage application: can't retrieve staging status")
        end

        if @app.staging_task_id != task_id
          raise Errors::ApiError.new_from_details('StagingError', 'failed to stage application: another staging request was initiated')
        end

        if @app.staging_failed?
          raise Errors::ApiError.new_from_details('StagingError', STAGING_ALREADY_FAILURE_MSG)
        end
      end

      def staging_completion(stager_response)
        instance_was_started_by_dea = !!stager_response.droplet_hash
        @app.db.transaction do
          @app.lock!
          @app.mark_as_staged
          @app.update_detected_buildpack(stager_response.detected_buildpack, stager_response.buildpack_key)
          @app.current_droplet.update_detected_start_command(stager_response.detected_start_command) if @app.current_droplet
        end

        @dea_pool.mark_app_started(dea_id: @stager_id, app_id: @app.guid) if instance_was_started_by_dea

        @completion_callback.call(started_instances: instance_was_started_by_dea ? 1 : 0) if @completion_callback
      end

      def staging_timeout
        @config[:staging][:timeout_in_seconds]
      end

      def staging_task_disk_mb
        [@config[:staging][:minimum_staging_disk_mb] || 4096, @app.disk_quota].max
      end

      def staging_task_memory_mb
        [
          (@config[:staging] && @config[:staging][:minimum_staging_memory_mb] || 1024),
          @app.memory
        ].max
      end

      def logger
        @logger ||= Steno.logger('cc.app_stager')
      end
    end
  end
end
