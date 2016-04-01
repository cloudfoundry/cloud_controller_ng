module VCAP::CloudController
  module Diego
    class Stager
      def initialize(app, messenger, completion_handler, config)
        @app = app
        @messenger = messenger
        @completion_handler = completion_handler
        @config = config
      end

      def stage
        if @app.pending? && @app.staging_task_id
          @messenger.send_stop_staging_request(@app)
        end

        @app.mark_for_restaging
        @app.staging_task_id = VCAP.secure_uuid
        @app.save_changes

        send_stage_app_request
      rescue Errors::ApiError => e
        logger.error('stage.app', staging_guid: StagingGuid.from_app(@app), error: e)
        staging_complete(StagingGuid.from_app(@app), { error: { id: 'StagingError', message: e.message } })
        raise e
      end

      def staging_complete(staging_guid, staging_response)
        @completion_handler.staging_complete(staging_guid, staging_response)
      end

      def stop_stage
        @messenger.send_stop_staging_request(@app)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.stager.client')
      end

      def send_stage_app_request
        @messenger.send_stage_request(@app, @config)
      rescue Errors::ApiError => e
        raise e
      rescue => e
        raise Errors::ApiError.new_from_details('StagerError', e)
      end
    end
  end
end
