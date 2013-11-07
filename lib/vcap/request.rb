module VCAP
  module Request
    HEADER_NAME = "X-VCAP-Request-ID"
    HEADER_BROKER_API_VERSION = 'X-Broker-Api-Version'

    class << self
      def current_id=(request_id)
        Thread.current[:vcap_request_id] = request_id
      end

      def current_id
        Thread.current[:vcap_request_id]
      end
    end
  end
end
