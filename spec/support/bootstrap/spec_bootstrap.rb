require 'support/bootstrap/test_config'
require 'support/bootstrap/table_recreator'
require 'cloud_controller/seeds'
require 'cloud_controller/telemetry_logger'
require 'cloud_controller/steno_configurer'

module VCAP::CloudController
  module SpecBootstrap
    @initialized = false

    def self.init(recreate_tables: true)
      return if @initialized && !recreate_tables

      @initialized = true
      ENV['CC_TEST'] = 'true'
      FileUtils.mkdir_p(Paths::ARTIFACTS)

      log_filename = File.join(Paths::ARTIFACTS, 'spec.log')
      max_log_file_size_in_bytes = 100_000_000
      if File.exist?(log_filename) && File.size(log_filename) > max_log_file_size_in_bytes
        FileUtils.rm_f(log_filename)
      end
      logger = ActiveSupport::Logger.new(File.join(Paths::ARTIFACTS, 'telemetry_spec.log'))
      TelemetryLogger.init(logger)

      StenoConfigurer.new(level: 'debug2').configure do |steno_config_hash|
        steno_config_hash[:sinks] = [Steno::Sink::IO.for_file(log_filename)]
      end

      db_config = DbConfig.new

      if recreate_tables
        db_resetter = TableRecreator.new(db_config.connection)
        db_resetter.recreate_tables
      end

      DB.load_models(db_config.config, db_config.db_logger)
    end

    def self.seed
      Seeds.write_seed_data(TestConfig.config_instance)
    end
  end
end
