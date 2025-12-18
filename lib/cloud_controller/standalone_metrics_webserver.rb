require 'cloud_controller/execution_context'

module VCAP::CloudController
  class StandaloneMetricsWebserver
    def self.start_for_bosh_job(port)
      new(port).start
    end

    def initialize(port)
      @port = port
    end

    def start
      metrics_app = build_app

      Thread.new do
        server = Puma::Server.new(metrics_app)
        add_listener(server)
        server.run
      end
    end

    private

    def bosh_job_name
      VCAP::CloudController::ExecutionContext.from_process_type_env.capi_job_name
    end

    def build_app
      Rack::Builder.new do
        use Prometheus::Middleware::Exporter, path: '/metrics'

        # Return 404 for any other request
        map('/') { run ->(_env) { ['404', { 'Content-Type' => 'text/plain' }, ['Not Found']] } }
      end
    end

    def add_listener(server)
      if use_ssl?
        server.add_ssl_listener('127.0.0.1', @port, ssl_context)
      else
        logger.warn('Starting metrics webserver without TLS. This is not recommended for production environments.')
        server.add_tcp_listener('127.0.0.1', @port)
      end
    end

    def use_ssl?
      File.exist?(cert_path) && File.exist?(key_path) && File.exist?(ca_path)
    end

    def ssl_context
      context = Puma::MiniSSL::Context.new
      context.cert = cert_path
      context.key = key_path
      context.ca = ca_path
      context.verify_mode = Puma::MiniSSL::VERIFY_PEER | Puma::MiniSSL::VERIFY_FAIL_IF_NO_PEER_CERT
      context
    end

    def cert_path
      "/var/vcap/jobs/#{bosh_job_name}/config/certs/scrape.crt"
    end

    def key_path
      "/var/vcap/jobs/#{bosh_job_name}/config/certs/scrape.key"
    end

    def ca_path
      "/var/vcap/jobs/#{bosh_job_name}/config/certs/scrape_ca.crt"
    end

    def logger
      Steno.logger('companion_metrics_webserver')
    end
  end
end
