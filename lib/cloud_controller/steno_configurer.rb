module VCAP::CloudController
  class StenoConfigurer
    def initialize(logging_config)
      @config = logging_config || {}
    end

    def configure
      steno_config = Steno::Config.to_config_hash(@config)
      steno_config[:context] = Steno::Context::ThreadLocal.new

      if block_given?
        yield steno_config
      end

      Steno.init(Steno::Config.new(steno_config))
    end
  end
end
