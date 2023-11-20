require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new, prometheus_updater=CloudController::DependencyLocator.instance.prometheus_updater)
        @counter = 0
        @statsd = statsd
        @prometheus_updater = prometheus_updater
      end

      def start_request
        @counter += 1
        @statsd.gauge('cc.requests.outstanding.gauge', @counter)
        @statsd.increment 'cc.requests.outstanding'

        @prometheus_updater.increment_gauge_metric(:cc_requests_outstanding_total)
      end

      def complete_request(status)
        http_status_code = "#{status.to_s[0]}XX"
        http_status_metric = "cc.http_status.#{http_status_code}"
        @counter -= 1
        @statsd.gauge('cc.requests.outstanding.gauge', @counter)
        @statsd.batch do |batch|
          batch.decrement 'cc.requests.outstanding'
          batch.increment 'cc.requests.completed'
          batch.increment http_status_metric
        end

        @prometheus_updater.decrement_gauge_metric(:cc_requests_outstanding_total)
        @prometheus_updater.increment_counter_metric(:cc_requests_completed_total)
      end
    end
  end
end
