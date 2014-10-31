module VCAP::CloudController
  module Diego
    class Stager
      def initialize(app, messenger, completion_handler)
        @app = app
        @messenger = messenger
        @completion_handler = completion_handler
      end

      def stage
       @messenger.send_stage_request(@app)
      end

      def staging_complete(staging_response)
        @completion_handler.staging_complete(staging_response)
      end
    end
  end
end
