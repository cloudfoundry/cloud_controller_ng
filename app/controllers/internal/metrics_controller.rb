require 'prometheus/client'
require 'prometheus/client/formats/text'

module VCAP::CloudController
  module Internal
    # This controller is only used when the webserver is not Puma
    # When using Puma, the metrics are served by a separate webserver in the main process
    class MetricsController < RestController::BaseController
      allow_unauthenticated_access
      get '/internal/v4/metrics', :index

      def index
        CloudController::DependencyLocator.instance.periodic_updater.update! unless VCAP::CloudController::Config.config.get(:webserver) == 'puma'
        [200, Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)]
      end
    end
  end
end
