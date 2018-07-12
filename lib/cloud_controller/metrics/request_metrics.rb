require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new)
        @statsd = statsd
        @collect_metrics_for_routes = ['service_instances', 'service_bindings', 'service_keys']
      end

      def start_request
        @statsd.increment 'cc.requests.outstanding'
      end

      def complete_request(path, method, status)
        @statsd.batch do |batch|
          batch.decrement 'cc.requests.outstanding'
          batch.increment 'cc.requests.completed'
          batch.increment "cc.http_status.#{status.to_s[0]}XX"

          pos = path.index('/', 1)
          next if pos.nil?

          path_without_version = path[pos + 1..-1]
          @collect_metrics_for_routes.
            select { |route| path_without_version.start_with? route }.
            each { |route| batch.increment "cc.requests.#{route}.#{method.downcase}.http_status.#{status.to_s[0]}XX" }
        end
      end
    end
  end
end
