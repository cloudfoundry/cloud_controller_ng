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
        staging_task_id = @app.staging_task_id
        @app.update(staging_task_id: VCAP.secure_uuid)
        @messenger.send_stop_staging_request(@app, staging_task_id) if @app.pending?
        @messenger.send_stage_request(@app, @staging_config)
      end

      def staging_complete(staging_response)
        @completion_handler.staging_complete(staging_response)
      end
    end
  end
end
