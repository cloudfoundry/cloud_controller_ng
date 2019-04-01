require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new)
        @statsd = statsd
      end

      def start_request
        @statsd.increment 'cc.requests.outstanding'
      end

      def complete_request(status)
        @statsd.batch do |batch|
          batch.decrement 'cc.requests.outstanding'
          batch.increment 'cc.requests.completed'
          batch.increment "cc.http_status.#{status.to_s[0]}XX"
        end
      end
    end
  end
end
