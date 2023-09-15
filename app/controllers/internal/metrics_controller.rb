require 'prometheus/client'
require 'prometheus/client/formats/text'

module VCAP::CloudController
  module Internal
    class MetricsController < RestController::BaseController
      allow_unauthenticated_access
      get '/internal/v4/metrics', :index

      def index
        [200, Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)]
      end
    end
  end
end
