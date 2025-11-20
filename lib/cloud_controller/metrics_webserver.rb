require 'rack'
require 'prometheus/middleware/exporter'

module VCAP
  module CloudController
    class MetricsWebserver
      attr_reader :app
      @server

      def initialize
        @app = build_app
      end

      def start(config)
        @server = Puma::Server.new(@app)

        if config.get(:nginx, :metrics_socket).nil? || config.get(:nginx, :metrics_socket).empty?
          @server.add_tcp_listener('127.0.0.1', 9395)
        else
          @server.add_unix_listener(config.get(:nginx, :metrics_socket))
        end

        @server.run
      end

      def stop
        @server.stop(true)
      end

      private

      def build_app
        status_proc = method(:status)
        Rack::Builder.new do
          use Prometheus::Middleware::Exporter, path: '/internal/v4/metrics'

          map '/internal/v4/status' do
            run ->(_env) { status_proc.call }
          end

          map '/' do
            run lambda { |_env|
              # Return 404 for any other request
              ['404', { 'Content-Type' => 'text/plain' }, ['Not Found']]
            }
          end
        end
      end

      def status
        stats = Puma.stats_hash
        worker_statuses = stats[:worker_status]

        all_busy = all_workers_busy?(worker_statuses)
        current_requests_count_sum = worker_requests_count_sum(worker_statuses)

        track_request_count_increase(current_requests_count_sum)

        unhealthy = determine_unhealthy_state(all_busy)

        build_status_response(all_busy, unhealthy)
      rescue StandardError => e
        [500, { 'Content-Type' => 'text/plain' }, ["Readiness check error: #{e}"]]
      end

      def track_request_count_increase(current_requests_count_sum)
        now = Time.now
        prev = @previous_requests_count_sum

        @last_requests_count_increase_time = now if prev.nil? || current_requests_count_sum > prev
        @previous_requests_count_sum = current_requests_count_sum
      end

      def determine_unhealthy_state(all_busy)
        return false unless all_busy && @last_requests_count_increase_time

        (Time.now - @last_requests_count_increase_time) > 60
      end

      def build_status_response(all_busy, unhealthy)
        if all_busy && unhealthy
          [503, { 'Content-Type' => 'text/plain' }, ['UNHEALTHY']]
        elsif all_busy
          [429, { 'Content-Type' => 'text/plain' }, ['BUSY']]
        else
          [200, { 'Content-Type' => 'text/plain' }, ['OK']]
        end
      end

      def all_workers_busy?(worker_statuses)
        worker_statuses.all? do |worker|
          worker[:last_status][:busy_threads] == worker[:last_status][:running]
        end
      end

      def worker_requests_count_sum(worker_statuses)
        worker_statuses.sum do |worker|
          worker[:last_status][:requests_count] || 0
        end
      end
    end
  end
end
