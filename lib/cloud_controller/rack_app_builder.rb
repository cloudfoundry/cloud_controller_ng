require 'syslog/logger'
require 'vcap_request_id'
require 'cors'
require 'request_metrics'
require 'request_logs'
require 'cef_logs'
require 'security_context_setter'
require 'rate_limiter'
require 'new_relic_custom_attributes'

module VCAP::CloudController
  class RackAppBuilder
    def build(config, request_metrics)
      token_decoder = VCAP::CloudController::UaaTokenDecoder.new(config.get(:uaa))
      configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)

      logger = access_log(config)

      Rack::Builder.new do
        use CloudFoundry::Middleware::RequestMetrics, request_metrics
        use CloudFoundry::Middleware::Cors, config.get(:allowed_cors_domains)
        use CloudFoundry::Middleware::VcapRequestId
        use CloudFoundry::Middleware::NewRelicCustomAttributes if config.get(:newrelic_enabled)
        use CloudFoundry::Middleware::SecurityContextSetter, configurer
        use CloudFoundry::Middleware::RequestLogs, Steno.logger('cc.api')
        if config.get(:rate_limiter, :enabled)
          use CloudFoundry::Middleware::RateLimiter, {
            logger: Steno.logger('cc.rate_limiter'),
            general_limit: config.get(:rate_limiter, :general_limit),
            unauthenticated_limit: config.get(:rate_limiter, :unauthenticated_limit),
            interval: config.get(:rate_limiter, :reset_interval_in_minutes),
          }
        end

        if config.get(:security_event_logging, :enabled)
          program_name = config.get(:logging, :syslog) || 'vcap.cloud_controller_ng' # TODO: default in config.rb, spec, or template
          use CloudFoundry::Middleware::CefLogs, Syslog::Logger.new(program_name), config.get(:local_route)
        end
        use Rack::CommonLogger, logger if logger

        if config.get(:development_mode) && config.get(:newrelic_enabled)
          require 'new_relic/rack/developer_mode'
          use NewRelic::Rack::DeveloperMode
        end

        map '/' do
          run FrontController.new(config)
        end

        map '/v3' do
          run Rails.application.app
        end
      end
    end

    private

    def access_log(config)
      if !config.get(:nginx, :use_nginx) && config.get(:logging, :file)
        access_filename = File.join(File.dirname(config.get(:logging, :file)), 'cc.access.log')
        access_log ||= File.open(access_filename, 'a')
        access_log.sync = true
        access_log
      end
    end
  end
end
