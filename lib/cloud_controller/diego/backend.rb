module VCAP::CloudController
  module Diego
    class Backend
      def initialize(app, messenger, protocol)
        @app = app
        @messenger = messenger
        @protocol = protocol
      end

      def requires_restage?
        # The DEA staging process doesn't know to set the start command, this happens
        # when an existing DEA based app is switched over to running on Diego
        @app.detected_start_command.empty?
      end

      def stage
       @messenger.send_stage_request(@app)
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

      def desire_app_message
        @protocol.desire_app_message(@app)
      end
    end
  end
end
