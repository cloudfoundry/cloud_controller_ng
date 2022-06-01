require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new, prometheus_updater=PrometheusUpdater.new)
        @counter = 0
        @statsd = statsd
        @prometheus_updater = prometheus_updater
      end

      def start_request
        @counter += 1
        @statsd.gauge('cc.requests.outstanding.gauge', @counter)
        @statsd.increment 'cc.requests.outstanding'

        @prometheus_updater.update_gauge_metric(:cc_requests_outstanding_gauge, @counter, 'Requests Outstanding Gauge')
        @prometheus_updater.increment_gauge_metric(:cc_requests_outstanding, 'Requests Outstanding')
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

        @prometheus_updater.update_gauge_metric(:cc_requests_outstanding_gauge, @counter, 'Requests Outstanding Gauge')
        @prometheus_updater.decrement_gauge_metric(:cc_requests_outstanding, 'Requests Outstanding')
        @prometheus_updater.increment_gauge_metric(:cc_requests_completed, 'Requests Completed')
        @prometheus_updater.increment_gauge_metric(http_status_metric.gsub('.', '_').to_sym, "Times HTTP status #{http_status_code} have been received")
      end
    end
  end
end
