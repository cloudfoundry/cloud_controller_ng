module VCAP::CloudController
  module Diego
    class Stager
      def initialize(app, messenger, completion_handler, staging_config)
        @app = app
        @messenger = messenger
        @completion_handler = completion_handler
        @staging_config = staging_config
      end

      def stage_package(_, _, _, _, _, _)
        raise NotImplementedError
      end

      def stage_app
        @messenger.send_stop_staging_request(@app) if @app.pending?
        @app.mark_for_restaging
        @app.staging_task_id = VCAP.secure_uuid
        @app.save_changes
        @messenger.send_stage_request(@app, @staging_config)
      rescue => e
        @app.mark_as_failed_to_stage
        @app.save_changes
        raise e
      end

      def staging_complete(staging_guid, staging_response)
        @completion_handler.staging_complete(staging_guid, staging_response)
      end
    end
  end
end
