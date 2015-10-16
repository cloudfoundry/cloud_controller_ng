require 'vcap_request_id'
require 'cors'
require 'request_metrics'
require 'request_logs'

module VCAP::CloudController
  class RackAppBuilder
    def build(config, request_metrics)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])

      logger = access_log(config)

      Rack::Builder.new do
        use CloudFoundry::Middleware::RequestMetrics, request_metrics
        use CloudFoundry::Middleware::Cors, config[:allowed_cors_domains]
        use CloudFoundry::Middleware::VcapRequestId
        use CloudFoundry::Middleware::RequestLogs, Steno.logger('cc.api')
        use Rack::CommonLogger, logger if logger

        if config[:development_mode] && config[:newrelic_enabled]
          require 'new_relic/rack/developer_mode'
          use NewRelic::Rack::DeveloperMode
        end

        map '/' do
          run FrontController.new(config, token_decoder)
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
        return access_log
      end
    end
  end
end
