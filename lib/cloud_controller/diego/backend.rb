module VCAP::CloudController
  module Diego
    class Backend
      def initialize(app, diego_client)
        @app = app
        @diego_client = diego_client
      end

      def scale
        @diego_client.send_desire_request(@app)
      end

      def start(_={})
        @diego_client.send_desire_request(@app)
      end

      def stop
        @diego_client.send_desire_request(@app)
      end
    end
  end
end
