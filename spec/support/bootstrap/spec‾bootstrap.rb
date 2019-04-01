require 'support/bootstrap/test_config'
require 'support/bootstrap/table_recreator'
require 'cloud_controller/seeds'

module VCAP::CloudController
  module SpecBootstrap
    def self.init
      ENV['CC_TEST'] = 'true'
      FileUtils.mkdir_p(Paths::ARTIFACTS)

      log_filename = File.join(Paths::ARTIFACTS, 'spec.log')
      max_log_file_size_in_bytes = 100_000_000
      if File.exist?(log_filename) && File.size(log_filename) > max_log_file_size_in_bytes
        FileUtils.rm_f(log_filename)
      end

      StenoConfigurer.new(level: 'debug2').configure do |steno_config_hash|
        steno_config_hash[:sinks] = [Steno::Sink::IO.for_file(log_filename)]
      end

      db_config = DbConfig.new

      db_resetter = TableRecreator.new(db_config.connection)
      db_resetter.recreate_tables

      DB.load_models(db_config.config, db_config.db_logger)
    end

    def self.seed
      Seeds.write_seed_data(TestConfig.config_instance)
    end
  end
end
