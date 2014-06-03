module DbConfig
  def self.name
    "cc_test_#{ENV["TEST_ENV_NUMBER"]}"
  end

  def self.connection_string
    case connection_prefix
      when /(mysql|postgres)/
        "#{connection_prefix}/#{name}"
      when /sqlite/
        "sqlite:///tmp/#{name}.db"
    end
  end

  def self.connection_prefix
    default_connection_prefix = {
        "mysql" => "mysql2://root@localhost:3306",
        "postgres" => "postgres://postgres@localhost:5432",
        "sqlite" => "sqlite:///tmp/",
    }

    if ENV["TRAVIS"] != "true"
      default_connection_prefix["mysql"] = "mysql2://root:password@localhost:3306"
    end

    ENV["DB_CONNECTION"] ||= default_connection_prefix[ENV["DB"]]
  end
end
