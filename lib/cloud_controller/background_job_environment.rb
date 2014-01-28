class BackgroundJobEnvironment
  def initialize(config)
    @config = config
    Steno.init(Steno::Config.new(:sinks => [Steno::Sink::IO.new(STDOUT)]))
  end

  def setup_environment
    VCAP::CloudController::DB.load_models(@config.fetch(:db), Steno.logger("cc.background"))
    VCAP::CloudController::Config.configure_components(@config)

    Thread.new do
      EM.run do
        message_bus = MessageBus::Configurer.new(
          :servers => @config[:message_bus_servers],
          :logger => Steno.logger("cc.message_bus")).go

        # The worker should not interact with DEA
        # so we using null object for stager and dea pool
        # The AppObserver should be refactored and don't depend on stager and dea pools
        no_op_staging_pool = Object.new
        no_op_dea_pool = Object.new
        VCAP::CloudController::AppObserver.configure(@config, message_bus, no_op_dea_pool, no_op_staging_pool)
      end
    end
  end
end
