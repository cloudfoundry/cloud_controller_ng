Sequel.migration do
  up do
    if database_type == :postgres
      run <<-SQL
        CREATE TABLE asg_timestamps (
          id INT PRIMARY KEY DEFAULT 1,
          last_update TIMESTAMP
        );
        CREATE UNIQUE INDEX asg_change_singleton ON asg_timestamps ((true));
      SQL
    else
      run <<-SQL
          CREATE TABLE asg_timestamps (
            id INT PRIMARY KEY DEFAULT 1,
            last_update TIMESTAMP,
            unique_value ENUM('lockme') NOT NULL DEFAULT 'lockme'
          );

          CREATE UNIQUE INDEX asg_change_singleton ON asg_timestamps (unique_value);
      SQL
    end
  end

  down do
    drop_table(:asg_timestamps)
  end
end
