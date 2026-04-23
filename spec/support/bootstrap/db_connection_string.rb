class DbConnectionString
  def initialize(connection_string: ENV.fetch('DB_CONNECTION_STRING', nil), db_type: ENV.fetch('DB', nil))
    @connection_string = connection_string || default_connection_string(db_type)
  end

  def to_s
    @connection_string
  end

  private

  def default_connection_string(db_type)
    "#{default_connection_prefix(db_type)}/#{default_name}"
  end

  def default_connection_prefix(db_type)
    postgres = ENV.fetch('POSTGRES_CONNECTION_PREFIX', 'postgres://postgres@localhost:5432')
    {
      'mysql' => ENV.fetch('MYSQL_CONNECTION_PREFIX', 'mysql2://root:password@localhost:3306'),
      'postgres' => postgres
    }.fetch(db_type, postgres)
  end

  def default_name
    test_env_number = ENV.fetch('TEST_ENV_NUMBER', '')
    test_env_number.empty? ? 'cc_test_1' : "cc_test_#{test_env_number}"
  end
end
