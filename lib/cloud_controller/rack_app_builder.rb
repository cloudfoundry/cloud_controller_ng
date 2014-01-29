module VCAP::CloudController
  class RackAppBuilder
    def build(globals, config)
      token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
      Rack::Builder.new do
        use Rack::CommonLogger

        if config[:development_mode]
          require 'new_relic/rack/developer_mode'
          use NewRelic::Rack::DeveloperMode
        end

        globals.setup!

        map "/" do
          run Controller.new(config, token_decoder)
        end
      end
    end
  end
end
