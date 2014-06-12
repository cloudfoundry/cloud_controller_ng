require "bootstrap/default_config"
require "bootstrap/table_recreator"

module VCAP::CloudController
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      FileUtils.mkdir_p(artifacts_dir)

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

      Seeds.create_seed_quota_definitions(config)
    end

    def db
      Thread.current[:db] ||= DB.connect(config.fetch(:db), db_logger)
    end

    private

    def config
      @config ||= DefaultConfig.for_specs
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

    def spec_dir
      File.expand_path("..", File.dirname(__FILE__))
    end

    def artifacts_dir
      File.join(spec_dir, "artifacts")
    end

    def artifact_filename(name)
      File.join(artifacts_dir, name)
    end

    def log_filename
      artifact_filename("spec.log")
    end
  end
end

$spec_env = VCAP::CloudController::SpecEnvironment.new
