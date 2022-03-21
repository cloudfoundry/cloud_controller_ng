require 'prometheus/client'
require 'cloud_controller/metrics/prom_updater'
class MetricsController < ActionController::Base
  def index
    @registry = Prometheus::Client.registry
    periodic_updater = VCAP::CloudController::Metrics::PeriodicUpdater.new(
      Time.now.utc,
      Steno::Sink::Counter.new,
      Steno.logger('cc.api'),
      [
        VCAP::CloudController::Metrics::PromUpdater.new(@registry)
      ])
    periodic_updater.update!
    render status: :ok, plain: Prometheus::Client::Formats::Text.marshal(@registry)
  end
end
