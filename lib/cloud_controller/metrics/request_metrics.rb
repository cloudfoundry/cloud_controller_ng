require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd_updater=CloudController::DependencyLocator.instance.statsd_updater, prometheus_updater=CloudController::DependencyLocator.instance.prometheus_updater)
        @statsd_updater = statsd_updater
        @prometheus_updater = prometheus_updater
      end

      def start_request
        @statsd_updater.start_request
        @prometheus_updater.increment_gauge_metric(:cc_requests_outstanding_total)
      end

      def complete_request(status)
        @statsd_updater.complete_request(status)

        @prometheus_updater.increment_counter_metric(:cc_requests_completed_total)
        @prometheus_updater.decrement_gauge_metric(:cc_requests_outstanding_total)
      end
    end
  end
end
