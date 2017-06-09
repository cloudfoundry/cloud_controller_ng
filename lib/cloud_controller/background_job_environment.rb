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
        message_bus = nil
        # The AppObserver need no knowledge of the DEA or stager pools
        # so we are passing in no-op objects for these arguments
        no_op_dea_pool = Object.new

        runners = VCAP::CloudController::Runners.new(@config, message_bus, no_op_dea_pool)
        CloudController::DependencyLocator.instance.register(:runners, runners)

        stagers = VCAP::CloudController::Stagers.new(@config, message_bus, no_op_dea_pool)
        CloudController::DependencyLocator.instance.register(:stagers, stagers)

        VCAP::CloudController::AppObserver.configure(stagers, runners)
      end
    end

    if block_given?
      yield

      stop
    end
  end

  def stop
    EM.stop if EM.reactor_running?
  end
end
