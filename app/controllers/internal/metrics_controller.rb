require 'prometheus/client'
require 'prometheus/client/formats/text'
require 'cloud_controller/metrics/prometheus_updater'

module VCAP::CloudController
  module Internal
    class MetricsController < RestController::BaseController
      allow_unauthenticated_access
      get '/internal/v4/metrics', :index
      @start_time = Time.now.utc

      def index
        periodic_updater = CloudController::DependencyLocator.instance.periodic_updater
        periodic_updater.update!
        [200, Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)]
      end
    end
  end
end
