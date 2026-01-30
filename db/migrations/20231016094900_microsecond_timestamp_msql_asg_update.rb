Sequel.migration do
  up do
    MIN_SERVER_VERSION = 50_605
    raise "Unsupported MySQL version #{server_version}, required >= #{MIN_SERVER_VERSION}" if server_version < MIN_SERVER_VERSION

    if self.class.name.match?(/mysql/i)
      run <<~SQL.squish
        ALTER TABLE asg_timestamps MODIFY last_update TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
      SQL
    end
  end

  down do
    if self.class.name.match?(/mysql/i)
      run <<~SQL.squish
        ALTER TABLE asg_timestamps MODIFY last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      SQL
    end
  end
end
