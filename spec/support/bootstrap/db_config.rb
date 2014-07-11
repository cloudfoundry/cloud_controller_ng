module DbConfig
  def self.name
    if ENV["DB_CONNECTION_STRING"]
      ENV["DB_CONNECTION_STRING"].split("/").last
    elsif ENV["TEST_ENV_NUMBER"]
      "cc_test_#{ENV["TEST_ENV_NUMBER"]}"
    else
      "cc_test"
    end
  end

  def self.connection_string
    ENV["DB_CONNECTION_STRING"] ||= "#{connection_prefix}/#{name}"
  end

  def self.connection_prefix
    default_connection_prefix = {
        "mysql" => "mysql2://root:password@localhost:3306",
        "postgres" => "postgres://postgres@localhost:5432"
    }

    if ENV["TRAVIS"] == "true"
      default_connection_prefix["mysql"] = "mysql2://root@localhost:3306"
    end

    db_type = ENV["DB"] || "postgres"
    ENV["DB_CONNECTION"] ||= default_connection_prefix[db_type]
  end

  def self.config
    {
      :log_level => "debug",
      :database => DbConfig.connection_string,
      :pool_timeout => 10
    }
  end

  def self.connection
    Thread.current[:db] ||= VCAP::CloudController::DB.connect(config, db_logger)
  end

  def self.db_logger
    return @db_logger if @db_logger
    @db_logger = Steno.logger("cc.db")
    if ENV["DB_LOG_LEVEL"]
      level = ENV["DB_LOG_LEVEL"].downcase.to_sym
      @db_logger.level = level if Steno::Logger::LEVELS.include? level
    end
    @db_logger
  end
end
