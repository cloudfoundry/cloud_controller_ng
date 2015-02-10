class BackgroundJobEnvironment
  def initialize(config)
    @config = config
    @log_counter = Steno::Sink::Counter.new

    VCAP::CloudController::StenoConfigurer.new(config[:logging]).configure do |steno_config_hash|
      steno_config_hash[:sinks] << @log_counter
    end
  end

  def setup_environment
    VCAP::CloudController::DB.load_models(@config.fetch(:db), Steno.logger('cc.background'))
    VCAP::CloudController::Config.configure_components(@config)

    Thread.new do
      EM.run do
        message_bus = MessageBus::Configurer.new(
          servers: @config[:message_bus_servers],
          logger: Steno.logger('cc.message_bus')).go

        # The AppObserver need no knowledge of the DEA or stager pools
        # so we are passing in no-op objects for these arguments
        no_op_staging_pool = Object.new
        no_op_dea_pool = Object.new

        runners = VCAP::CloudController::Runners.new(@config, message_bus, no_op_dea_pool, no_op_staging_pool)
        stagers = VCAP::CloudController::Stagers.new(@config, message_bus, no_op_dea_pool, no_op_staging_pool, runners)
        VCAP::CloudController::AppObserver.configure(stagers, runners)

        blobstore_url_generator = CloudController::DependencyLocator.instance.blobstore_url_generator
        VCAP::CloudController::Dea::Client.configure(@config, message_bus, no_op_dea_pool, no_op_staging_pool, blobstore_url_generator)
      end
    end
  end
end
