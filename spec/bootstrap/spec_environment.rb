require "bootstrap/test_config"
require "bootstrap/table_recreator"

module VCAP::CloudController
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      FileUtils.mkdir_p(Paths::ARTIFACTS)

      log_filename = File.join(Paths::ARTIFACTS, "spec.log")
      max_log_file_size_in_bytes = 100_000_000
      if File.exist?(log_filename) && File.size(log_filename) > max_log_file_size_in_bytes
        FileUtils.rm_f(log_filename)
      end

      StenoConfigurer.new(level: "debug2").configure do |steno_config_hash|
        steno_config_hash[:sinks] = [Steno::Sink::IO.for_file(log_filename)]
      end

      db_resetter = TableRecreator.new(db)
      db_resetter.recreate_tables

      DB.load_models(config.fetch(:db), db_logger)
      Config.run_initializers(config)

      TestConfig.reset
      Seeds.write_seed_data(config)
    end

    def db
      Thread.current[:db] ||= DB.connect(config.fetch(:db), db_logger)
    end

    private

    def config
      @config ||= TestConfig.defaults
    end

    def db_logger
      return @db_logger if @db_logger
      @db_logger = Steno.logger("cc.db")
      if ENV["DB_LOG_LEVEL"]
        level = ENV["DB_LOG_LEVEL"].downcase.to_sym
        @db_logger.level = level if Steno::Logger::LEVELS.include? level
      end
      @db_logger
    end
  end
end

$spec_env = VCAP::CloudController::SpecEnvironment.new
