module VCAP::CloudController
  module Diego
    class Backend
      def initialize(app, messenger, protocol, completion_handler)
        @app = app
        @messenger = messenger
        @protocol = protocol
        @completion_handler = completion_handler
      end

      def requires_restage?
        # The DEA staging process doesn't know to set the start command, this happens
        # when an existing DEA based app is switched over to running on Diego
        @app.execution_metadata.empty? && @app.command.blank?
      end

      def stage
       @messenger.send_stage_request(@app)
      end

      def staging_complete(staging_response)
        @completion_handler.staging_complete(staging_response)
      end

      def scale
        @messenger.send_desire_request(@app)
      end

      def start(_={})
        @messenger.send_desire_request(@app)
      end

      def stop
        @messenger.send_desire_request(@app)
      end

      def update_routes
        @messenger.send_desire_request(@app)
      end

      def desire_app_message
        @protocol.desire_app_message(@app)
      end
    end
  end
end
