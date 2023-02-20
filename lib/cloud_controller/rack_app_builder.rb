require 'syslog/logger'
require 'vcap_request_id'
require 'cors'
require 'request_metrics'
require 'request_logs'
require 'cef_logs'
require 'security_context_setter'
require 'rate_limiter'
require 'service_broker_rate_limiter'
require 'rate_limiter_v2_api'
require 'new_relic_custom_attributes'
require 'zipkin'
require 'block_v3_only_roles'

module VCAP::CloudController
  class RackAppBuilder
    def build(config, request_metrics, request_logs)
      token_decoder = VCAP::CloudController::UaaTokenDecoder.new(config.get(:uaa))
      configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)

      logger = access_log(config)

      Rack::Builder.new do
        use CloudFoundry::Middleware::RequestMetrics, request_metrics
        use CloudFoundry::Middleware::Cors, config.get(:allowed_cors_domains)
        use CloudFoundry::Middleware::VcapRequestId
        use CloudFoundry::Middleware::NewRelicCustomAttributes if config.get(:newrelic_enabled)
        use Honeycomb::Rack::Middleware, client: Honeycomb.client if config.get(:honeycomb)
        use CloudFoundry::Middleware::SecurityContextSetter, configurer
        use CloudFoundry::Middleware::Zipkin
        use CloudFoundry::Middleware::RequestLogs, request_logs
        if config.get(:rate_limiter, :enabled)
          use CloudFoundry::Middleware::RateLimiter, {
            logger: Steno.logger('cc.rate_limiter'),
            per_process_general_limit: config.get(:rate_limiter, :per_process_general_limit),
            global_general_limit: config.get(:rate_limiter, :global_general_limit),
            per_process_unauthenticated_limit: config.get(:rate_limiter, :per_process_unauthenticated_limit),
            global_unauthenticated_limit: config.get(:rate_limiter, :global_unauthenticated_limit),
            interval: config.get(:rate_limiter, :reset_interval_in_minutes),
          }
        end
        if config.get(:max_concurrent_service_broker_requests) > 0
          CloudFoundry::Middleware::ServiceBrokerRequestCounter.instance.limit = config.get(:max_concurrent_service_broker_requests)
          use CloudFoundry::Middleware::ServiceBrokerRateLimiter, {
            logger: Steno.logger('cc.service_broker_rate_limiter'),
            broker_timeout_seconds: config.get(:broker_client_timeout_seconds),
          }
        end
        if config.get(:rate_limiter_v2_api, :enabled)
          use CloudFoundry::Middleware::RateLimiterV2API, {
            logger: Steno.logger('cc.rate_limiter_v2_api'),
            per_process_general_limit: config.get(:rate_limiter_v2_api, :per_process_general_limit),
            global_general_limit: config.get(:rate_limiter_v2_api, :global_general_limit),
            per_process_admin_limit: config.get(:rate_limiter_v2_api, :per_process_admin_limit),
            global_admin_limit: config.get(:rate_limiter_v2_api, :global_admin_limit),
            interval: config.get(:rate_limiter_v2_api, :reset_interval_in_minutes),
          }
        end

        if config.get(:security_event_logging, :enabled)
          use CloudFoundry::Middleware::CefLogs, Logger.new(config.get(:security_event_logging, :file)), config.get(:local_route)
        end
        use Rack::CommonLogger, logger if logger

        map '/' do
          use CloudFoundry::Middleware::BlockV3OnlyRoles, { logger: Steno.logger('cc.unsupported_roles') }
          run FrontController.new(config)
        end

        map '/v3' do
          run Rails.application.app
        end

        map '/healthz' do
          run lambda { |_| [200, { 'Content-Type' => 'application/json' }, ['OK']] }
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
