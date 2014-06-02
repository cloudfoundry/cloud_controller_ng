module VCAP::CloudController
  MAX_LOG_FILE_SIZE_IN_BYTES = 100_000_000
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      FileUtils.mkdir_p(artifacts_dir)

      if File.exist?(log_filename) && File.size(log_filename) > MAX_LOG_FILE_SIZE_IN_BYTES
        FileUtils.rm_f(log_filename)
      end

      StenoConfigurer.new(level: "debug2").configure do |steno_config_hash|
        steno_config_hash[:sinks] = [Steno::Sink::IO.for_file(log_filename)]
      end

      reset_database

      VCAP::CloudController::DB.load_models(config.fetch(:db), db_logger)
      VCAP::CloudController::Config.run_initializers(config)
      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
    end

    def reset_database_with_seeds
      reset_database
      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
      VCAP::CloudController::Seeds.create_seed_stacks
    end

    def db
      Thread.current[:db] ||= VCAP::CloudController::DB.connect(config.fetch(:db), db_logger)
    end

    def config
      config_file = File.expand_path("../config/cloud_controller.yml", File.dirname(__FILE__))
      config_hash = VCAP::CloudController::Config.from_file(config_file)

      config_hash.update(
          :nginx => {:use_nginx => true},
          :resource_pool => {
              :resource_directory_key => "spec-cc-resources",
              :fog_connection => {
                  :provider => "AWS",
                  :aws_access_key_id => "fake_aws_key_id",
                  :aws_secret_access_key => "fake_secret_access_key",
              },
          },
          :packages => {
              :app_package_directory_key => "cc-packages",
              :fog_connection => {
                  :provider => "AWS",
                  :aws_access_key_id => "fake_aws_key_id",
                  :aws_secret_access_key => "fake_secret_access_key",
              },
          },
          :droplets => {
              :droplet_directory_key => "cc-droplets",
              :fog_connection => {
                  :provider => "AWS",
                  :aws_access_key_id => "fake_aws_key_id",
                  :aws_secret_access_key => "fake_secret_access_key",
              },
          },

          :db => {
              :log_level => "debug",
              :database => db_connection_string,
              :pool_timeout => 10
          }
      )

      config_hash
    end

    private

    def reset_database
      prepare_database

      db.tables.each do |table|
        drop_table_unsafely(table)
      end

      DBMigrator.new(db).apply_migrations
    end

    def db_connection_string
      if ENV["DB_CONNECTION"]
        "#{ENV["DB_CONNECTION"]}/cc_test_#{ENV["TEST_ENV_NUMBER"]}"
      else
        "sqlite:///tmp/cc_test#{ENV["TEST_ENV_NUMBER"]}.db"
      end
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
      File.expand_path("..", __FILE__)
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

    def prepare_database
      if db.database_type == :postgres
        db.execute("CREATE EXTENSION IF NOT EXISTS citext")
      end
    end

    def drop_table_unsafely(table)
      case db.database_type
        when :sqlite
          db.execute("PRAGMA foreign_keys = OFF")
          db.drop_table(table)
          db.execute("PRAGMA foreign_keys = ON")

        when :mysql
          db.execute("SET foreign_key_checks = 0")
          db.drop_table(table)
          db.execute("SET foreign_key_checks = 1")

        # Postgres uses CASCADE directive in DROP TABLE
        # to remove foreign key contstraints.
        # http://www.postgresql.org/docs/9.2/static/sql-droptable.html
        else
          db.drop_table(table, :cascade => true)
      end
    end
  end
end

$spec_env = VCAP::CloudController::SpecEnvironment.new
