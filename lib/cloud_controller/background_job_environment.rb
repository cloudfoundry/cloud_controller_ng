class BackgroundJobEnvironment
  def initialize(config)
    @config = config
  end

  def setup_environment
    connect_to_database
    VCAP::CloudController::Config.configure(@config)
  end

  private
  def connect_to_database(log_tag="cc.background")
    Steno.init(Steno::Config.new(:sinks => [Steno::Sink::IO.new(STDOUT)]))
    db_logger = Steno.logger(log_tag)
    VCAP::CloudController::DB.load_models(@config.fetch(:db), db_logger)
  end
end
