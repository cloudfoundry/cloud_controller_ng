module VCAP::CloudController
  class RouteDestinationUpdate
    class Error < StandardError
    end

    class << self
      def update(destination, message)
        validate_protocol_matches_route!(destination, message)

        destination.db.transaction do
          destination.lock!

          destination.protocol = message.protocol if message.requested? :protocol

          destination.save
        end

        runners = CloudController::DependencyLocator.instance.runners
        destination.processes.each do |process|
          notify_backend_of_route_update(process, runners)
        end

        destination
      end

      private

      def notify_backend_of_route_update(process, runners)
        runners.runner_for_process(process).update_routes if process.staged? && process.started?
      rescue Diego::Runner::CannotCommunicateWithDiegoError => e
        logger.error("failed communicating with diego backend: #{e.message}")
      end

      def validate_protocol_matches_route!(destination, message)
        if destination.route&.protocol == 'tcp'
          raise Error.new("Destination protocol must be 'tcp' if the parent route's protocol is 'tcp'") unless message.protocol == 'tcp'
        elsif message.protocol == 'tcp'
          raise Error.new("Destination protocol must be 'http1' or 'http2' if the parent route's protocol is 'http'")
        end
      end

      def logger
        @logger ||= Steno.logger('cc.route_destination_update')
      end
    end
  end
end
