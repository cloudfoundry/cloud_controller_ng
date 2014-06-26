module VCAP::CloudController
  class RackAppBuilder
    def build(config)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
      Rack::Builder.new do
        use Rack::CommonLogger

        if config[:development_mode] && config[:newrelic_enabled]
          require 'new_relic/rack/developer_mode'
          use NewRelic::Rack::DeveloperMode
        end

        map "/" do
          run FrontController.new(config, token_decoder)
        end
      end
    end
  end
end
