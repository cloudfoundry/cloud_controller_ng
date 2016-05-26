module VCAP::CloudController
  module Diego
    class Stager
      attr_writer :messenger

      def initialize(process, config)
        @process = process
        @config = config
      end

      def stage
        if @process.pending? && @process.staging_task_id
          messenger.send_stop_staging_request
        end

        @process.mark_for_restaging
        @process.staging_task_id = VCAP.secure_uuid
        @process.save_changes

        send_stage_app_request
      rescue CloudController::Errors::ApiError => e
        logger.error('stage.app', staging_guid: StagingGuid.from_process(@process), error: e)
        staging_complete(StagingGuid.from_process(@process), { error: { id: 'StagingError', message: e.message } })
        raise e
      end

      def staging_complete(staging_guid, staging_response)
        completion_handler.staging_complete(staging_guid, staging_response)
      end

      def stop_stage
        messenger.send_stop_staging_request
      end

      def messenger
        @messenger ||= Diego::Messenger.new(@process)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.stager.client')
      end

      def send_stage_app_request
        messenger.send_stage_request(@config)
      rescue CloudController::Errors::ApiError => e
        raise e
      rescue => e
        raise CloudController::Errors::ApiError.new_from_details('StagerError', e)
      end

      def completion_handler
        if @process.docker?
          Diego::Docker::StagingCompletionHandler.new
        else
          Diego::Buildpack::StagingCompletionHandler.new
        end
      end
    end
  end
end
