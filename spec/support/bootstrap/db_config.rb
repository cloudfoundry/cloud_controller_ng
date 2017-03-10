class DbConfig
  def initialize(connection_string: ENV['DB_CONNECTION_STRING'], db_type: ENV['DB'])
    @connection_string = connection_string || default_connection_string(db_type || 'postgres')
    initialize_environment_for_cc_spawning
  end

  attr_reader :connection_string

  def name
    connection_string.split('/').last
  end

  def config
    configure = {
      log_level: 'debug',
      database: connection_string,
      pool_timeout: 10
    }
    if ENV['USEAZURESQL'] == 'true'
      configure[:azure] = true
    end
    configure
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
      'mysql' => 'mysql2://root:password@localhost:3306',
      'mysql_travis' => 'mysql2://root@localhost:3306',
      'postgres' => 'postgres://postgres@localhost:5432',
      'mssql' => 'tinytds://diego:Password-123@localhost:1433'
    }

    db_type = 'mysql_travis' if ENV['TRAVIS'] == 'true' && db_type == 'mysql'

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
