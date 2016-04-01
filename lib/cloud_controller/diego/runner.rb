module VCAP::CloudController
  module Diego
    class Runner
      class CannotCommunicateWithDiegoError < StandardError; end

      def initialize(app, messenger, protocol, default_health_check_timeout)
        @app = app
        @messenger = messenger
        @protocol = protocol
        @default_health_check_timeout = default_health_check_timeout
      end

      def scale
        raise VCAP::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @app.started?
        with_logging('scale') { @messenger.send_desire_request(@app, @default_health_check_timeout) }
      end

      def start(_={})
        with_logging('start') { @messenger.send_desire_request(@app, @default_health_check_timeout) }
      end

      def update_routes
        raise VCAP::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @app.started?
        with_logging('update_route') { @messenger.send_desire_request(@app, @default_health_check_timeout) unless @app.staging? }
      end

      def desire_app_message
        @protocol.desire_app_message(@app, @default_health_check_timeout)
      end

      def stop
        with_logging('stop_app') { @messenger.send_stop_app_request(@app) }
      end

      def stop_index(index)
        with_logging('stop_index') { @messenger.send_stop_index_request(@app, index) }
      end

      def with_logging(action=nil)
        yield
      rescue StandardError => e
        return raise e unless diego_not_responding_error?(e)
        logger.error "Cannot communicate with diego - tried to send #{action}"
        raise CannotCommunicateWithDiegoError.new(e.message)
      end

      private

      def diego_not_responding_error?(e)
        /getaddrinfo/ =~ e.message
      end

      def logger
        @logger ||= Steno.logger('cc.diego.runner')
      end
    end
  end
end
