require 'prometheus/client'
require 'prometheus/client/formats/text'
require 'cloud_controller/metrics/prometheus_updater'

module VCAP::CloudController
  module Internal
    class MetricsController < RestController::BaseController
      allow_unauthenticated_access
      get '/internal/v4/metrics', :index

      def index
        periodic_updater = VCAP::CloudController::Metrics::PeriodicUpdater.new(
          Time.now.utc,
          Steno::Sink::Counter.new,
          Steno.logger('cc.api'),
          [
            VCAP::CloudController::Metrics::StatsdUpdater.new,
            VCAP::CloudController::Metrics::PrometheusUpdater.new
          ])
        periodic_updater.update!
        [200, Prometheus::Client::Formats::Text.marshal(Prometheus::Client.registry)]
      end
    end
  end
end
