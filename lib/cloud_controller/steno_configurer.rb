require 'steno'
require 'steno/codec_rfc3339'
require 'steno/config'
require 'steno/context'

module VCAP::CloudController
  class StenoConfigurer
    def initialize(logging_config)
      @config = logging_config || {}
    end

    def configure
      steno_config = Steno::Config.to_config_hash(@config)
      steno_config[:context] = Steno::Context::ThreadLocal.new
      steno_config[:codec] = Steno::Codec::JsonRFC3339.new unless @config.dig(:format, :timestamp) == 'deprecated'

      if block_given?
        yield steno_config
      end

      Steno.init(Steno::Config.new(steno_config))
    end
  end
end
