require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new)
        @counter = 0
        @statsd = statsd
      end

      def start_request
        @counter += 1
        @statsd.gauge('cc.requests.outstanding.gauge', @counter)
        @statsd.increment 'cc.requests.outstanding'
      end

      def complete_request(status)
        @counter -= 1
        @statsd.gauge('cc.requests.outstanding.gauge', @counter)
        @statsd.batch do |batch|
          batch.decrement 'cc.requests.outstanding'
          batch.increment 'cc.requests.completed'
          batch.increment "cc.http_status.#{status.to_s[0]}XX"
        end
      end
    end
  end
end
