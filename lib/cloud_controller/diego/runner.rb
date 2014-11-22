module VCAP::CloudController
  module Diego
    class Runner
      def initialize(app, messenger, protocol)
        @app = app
        @messenger = messenger
        @protocol = protocol
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

      def desired_app_info
        raise NotImplementedError
      end

      def stop_index(index)
        @messenger.send_stop_index_request(@app, index)
      end
    end
  end
end
