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
      end

      private

      def validate_protocol_matches_route!(destination, message)
        if destination.route&.protocol == 'tcp'
          unless message.protocol == 'tcp'
            raise Error.new("Destination protocol must be 'tcp' if the parent route's protocol is 'tcp'")
          end
        elsif message.protocol == 'tcp'
          raise Error.new("Destination protocol must be 'http1' or 'http2' if the parent route's protocol is 'http'")
        end
      end
    end
  end
end
