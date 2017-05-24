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
      token_decoder = VCAP::CloudController::UaaTokenDecoder.new(config)
      configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)

      logger = access_log(config)

      Rack::Builder.new do
        use CloudFoundry::Middleware::RequestMetrics, request_metrics
        use CloudFoundry::Middleware::Cors, config[:allowed_cors_domains]
        use CloudFoundry::Middleware::VcapRequestId
        use CloudFoundry::Middleware::NewRelicCustomAttributes if config[:newrelic_enabled]
        use CloudFoundry::Middleware::SecurityContextSetter, configurer
        use CloudFoundry::Middleware::RequestLogs, Steno.logger('cc.api')
        if config[:rate_limiter][:enabled]
          use CloudFoundry::Middleware::RateLimiter, {
            logger: Steno.logger('cc.rate_limiter'),
            general_limit: config[:rate_limiter][:general_limit],
            unauthenticated_limit: config[:rate_limiter][:unauthenticated_limit],
            interval: config[:rate_limiter][:reset_interval_in_minutes]
          }
        end

        if HashUtils.dig(config, :security_event_logging, :enabled)
          use CloudFoundry::Middleware::CefLogs, Syslog::Logger.new(HashUtils.dig(config, :logging, :syslog) || 'vcap.cloud_controller_ng'), config[:local_route]
        end
        use Rack::CommonLogger, logger if logger

        if config[:development_mode] && config[:newrelic_enabled]
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
      if !config[:nginx][:use_nginx] && config[:logging][:file]
        access_filename = File.join(File.dirname(config[:logging][:file]), 'cc.access.log')
        access_log ||= File.open(access_filename, 'a')
        access_log.sync = true
        access_log
      end
    end
  end
end
