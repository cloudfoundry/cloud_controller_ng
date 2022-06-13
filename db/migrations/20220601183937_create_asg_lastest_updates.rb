Sequel.migration do
  up do
    if database_type == :postgres
      run <<-SQL
        CREATE TABLE asg_latest_updates (
          id INT PRIMARY KEY DEFAULT 1,
          last_update TIMESTAMP
        );
        CREATE UNIQUE INDEX asg_change_singleton ON asg_latest_updates ((true));
      SQL
    else
      run <<-SQL
          CREATE TABLE asg_latest_updates (
            id INT PRIMARY KEY DEFAULT 1,
            last_update TIMESTAMP,
            unique_value ENUM('lockme') NOT NULL DEFAULT 'lockme'
          );

          CREATE UNIQUE INDEX asg_change_singleton ON asg_latest_updates (unique_value);
      SQL
    end
  end

  down do
    drop_table(:asg_latest_updates)
  end
end
