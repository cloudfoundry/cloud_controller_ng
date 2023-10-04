require 'cloud_controller/db'
require 'cloud_controller/database_parts_parser'

class DbConfig
  def initialize(connection_string: ENV.fetch('DB_CONNECTION_STRING', nil), db_type: ENV.fetch('DB', nil))
    @connection_string = connection_string || default_connection_string(db_type || 'postgres')
    initialize_environment_for_cc_spawning
  end

  attr_reader :connection_string

  def name
    connection_string.split('/').last
  end

  def config
    {
      log_level: 'debug',
      db_connection_string: connection_string,
      database: VCAP::CloudController::DatabasePartsParser.database_parts_from_connection(connection_string),
      pool_timeout: 10,
      read_timeout: 3600,
      connection_validation_timeout: 3600
    }
  end

  def connection
    Thread.current[:db] ||= VCAP::CloudController::DB.connect(config, db_logger)
  end

  def db_logger
    return @db_logger if @db_logger

    @db_logger = Steno.logger('cc.db')
    if ENV['DB_LOG_LEVEL']
      level = ENV['DB_LOG_LEVEL'].downcase.to_sym
      @db_logger.level = level if Steno::Logger::LEVELS.include? level
    end
    @db_logger
  end

  def self.reset_environment
    ENV.delete('DB_CONNECTION_STRING')
  end

  private

  def initialize_environment_for_cc_spawning
    ENV['DB_CONNECTION_STRING'] = connection_string
  end

  def default_connection_string(db_type)
    "#{default_connection_prefix(db_type)}/#{default_name}"
  end

  def default_connection_prefix(db_type)
    default_connection_prefixes = {
      'mysql' => ENV['MYSQL_CONNECTION_PREFIX'] || 'mysql2://root:password@localhost:3306',
      'postgres' => ENV['POSTGRES_CONNECTION_PREFIX'] || 'postgres://postgres@localhost:5432'
    }

    default_connection_prefixes[db_type]
  end

  def default_name
    if ENV['TEST_ENV_NUMBER']
      "cc_test_#{ENV['TEST_ENV_NUMBER']}"
    else
      'cc_test'
    end
  end
end
