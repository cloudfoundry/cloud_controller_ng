module VCAP::CloudController
  module Diego
    class Runner
      class CannotCommunicateWithDiegoError < StandardError; end

      attr_writer :messenger

      def initialize(process, default_health_check_timeout)
        @process = process
        @default_health_check_timeout = default_health_check_timeout
      end

      def scale
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @process.started?
        with_logging('scale') { messenger.send_desire_request(@default_health_check_timeout) }
      end

      def start(_={})
        with_logging('start') { messenger.send_desire_request(@default_health_check_timeout) }
      end

      def update_routes
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', 'App not started') unless @process.started?
        with_logging('update_route') { messenger.send_desire_request(@default_health_check_timeout) unless @process.staging? }
      end

      def desire_app_message
        Diego::Protocol.new(@process).desire_app_message(@default_health_check_timeout)
      end

      def stop
        with_logging('stop_app') { messenger.send_stop_app_request }
      end

      def stop_index(index)
        with_logging('stop_index') { messenger.send_stop_index_request(index) }
      end

      def with_logging(action=nil)
        yield
      rescue StandardError => e
        return raise e unless diego_not_responding_error?(e)
        logger.error "Cannot communicate with diego - tried to send #{action}"
        raise CannotCommunicateWithDiegoError.new(e.message)
      end

      def messenger
        @messenger ||= Diego::Messenger.new(@process)
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
