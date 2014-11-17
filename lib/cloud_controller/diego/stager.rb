module VCAP::CloudController
  module Diego
    class Stager
      def initialize(app, messenger, completion_handler)
        @app = app
        @messenger = messenger
        @completion_handler = completion_handler
      end

      def stage
        staging_task_id = @app.staging_task_id
        @app.update(staging_task_id: VCAP.secure_uuid)
        @messenger.send_stop_staging_request(@app, staging_task_id) if @app.pending?
        @messenger.send_stage_request(@app)
      end

      def staging_complete(staging_response)
        @completion_handler.staging_complete(staging_response)
      end
    end
  end
end
