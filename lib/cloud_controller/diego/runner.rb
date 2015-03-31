module VCAP::CloudController
  module Diego
    class Runner
      def initialize(app, messenger, protocol, default_health_check_timeout)
        @app = app
        @messenger = messenger
        @protocol = protocol
        @default_health_check_timeout = default_health_check_timeout
      end

      def scale
        raise VCAP::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @app.started?
        @messenger.send_desire_request(@app, @default_health_check_timeout)
      end

      def start(_={})
        @messenger.send_desire_request(@app, @default_health_check_timeout)
      end

      def update_routes
        raise VCAP::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @app.started?
        @messenger.send_desire_request(@app, @default_health_check_timeout)
      end

      def desire_app_message
        @protocol.desire_app_message(@app, @default_health_check_timeout)
      end

      def desired_app_info
        raise NotImplementedError
      end

      def stop
        @messenger.send_stop_app_request(@app)
      end

      def stop_index(index)
        @messenger.send_stop_index_request(@app, index)
      end
    end
  end
end
