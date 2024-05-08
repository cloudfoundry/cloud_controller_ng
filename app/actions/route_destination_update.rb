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

        destination.processes.each do |process|
          ProcessRouteHandler.new(process).notify_backend_of_route_update
        end

        destination
      end

      private

      def validate_protocol_matches_route!(destination, message)
        if destination.route&.protocol == 'tcp'
          raise Error.new("Destination protocol must be 'tcp' if the parent route's protocol is 'tcp'") unless message.protocol == 'tcp'
        elsif message.protocol == 'tcp'
          raise Error.new("Destination protocol must be 'http1' or 'http2' if the parent route's protocol is 'http'")
        end
      end
    end
  end
end
