module VCAP::CloudController
  module Dea
    class PackageStagerTask
      class FailedToStage < StandardError
        attr_accessor :type, :message

        def initialize(type, message)
          @type    = type
          @message = message
        end
      end

      def initialize(config, message_bus, dea_pool, stager_pool)
        @config                  = config
        @message_bus             = message_bus
        @dea_pool                = dea_pool
        @stager_pool             = stager_pool
      end

      def staging_timeout
        @config[:staging][:timeout_in_seconds]
      end

      def logger
        @logger ||= Steno.logger('cc.package_stager')
      end

      def task_id
        @task_id ||= VCAP.secure_uuid
      end

      def stage(staging_message, &completion_callback)
        @stager_id = @stager_pool.find_stager(staging_message.stack, staging_message.memory_limit, staging_message.disk_limit)
        raise Errors::ApiError.new_from_details('StagingError', 'no available stagers') unless @stager_id

        subject = "staging.#{@stager_id}.start"
        @multi_message_bus_request = MultiResponseMessageBusRequest.new(@message_bus, subject)

        # Attempt to stop any in-flight staging for this app
        @message_bus.publish('staging.stop', app_id: staging_message.log_id)

        @completion_callback = completion_callback

        @dea_pool.reserve_app_memory(@stager_id, staging_message.memory_limit)
        @stager_pool.reserve_app_memory(@stager_id, staging_message.memory_limit)

        logger.info('staging.begin', droplet_guid: staging_message.droplet_guid)
        staging_result = EM.schedule_sync do |promise|
          # First response is blocking stage_app.
          @multi_message_bus_request.on_response(staging_timeout) do |response, error|
            logger.info('staging.first-response', droplet_guid: staging_message.droplet_guid, response: response, error: error)
            handle_first_response(staging_message.log_id, response, promise)
          end

          # Second message is received after package staging finished and
          # droplet was uploaded to the CC.
          # Second response does NOT block stage_package
          @multi_message_bus_request.on_response(staging_timeout) do |response, error|
            logger.info('staging.second-response', droplet_guid: staging_message.droplet_guid, response: response, error: error)
            handle_second_response(staging_message.log_id, response)
          end

          package_staging_request = staging_message.staging_request
          @multi_message_bus_request.request(package_staging_request)
        end

        staging_result
      end

      def handle_first_response(log_guid, response, promise)
        error = get_staging_error(response)

        if error
          Loggregator.emit_error(log_guid, "failed handling first response #{error.message}")
          logger.error("failed handling first response from stager with id #{@stager_id} response: #{response.inspect}, error: #{error.inspect}")
          promise.fail(error)
        else
          promise.deliver(StagingResponse.new(response))
        end
      end

      def handle_second_response(log_guid, response)
        @multi_message_bus_request.ignore_subsequent_responses
        error = get_staging_error(response)

        if error
          Loggregator.emit_error(log_guid, "encountered error: #{error.message}")
          logger.error "Encountered error on stager with id #{@stager_id}response: #{response.inspect}, error: #{error.inspect}"
        end

        process_response(log_guid, response, error)
      rescue => e
        Loggregator.emit_error(log_guid, "encountered error: #{e.message}")
        logger.error "Encountered error on stager with id #{@stager_id}: #{e}\n#{e.backtrace.join("\n")}"
      end

      def process_response(log_guid, response, error)
        # Defer potentially expensive operation
        # to avoid executing on reactor thread
        EM.defer do
          begin
            stager_response = StagingResponse.new(response)
            @completion_callback.call(stager_response, error) if @completion_callback
          rescue => e
            Loggregator.emit_error(log_guid, "Encountered error: #{e.message}")
            logger.error "Encountered error processing staging_response: #{e}\n#{e.backtrace.join("\n")}"
          end
        end
      end

      def get_staging_error(response)
        type = error_type(response)
        message = error_message(response)

        if type && message
          return FailedToStage.new(type, message)
        end

        nil
      end

      def error_message(response)
        if response.is_a?(String) || response.nil?
          "failed to stage:\n#{response}"
        elsif response['error_info']
          response['error_info']['message']
        elsif response['error']
          "failed to stage:\n#{response['error']}\n#{response['task_log']}"
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
    end
  end
end
