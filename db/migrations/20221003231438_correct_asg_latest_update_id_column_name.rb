Sequel.migration do
  up do
    if database_type == :mysql
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN `{:name=>:id}` to id;
      SQL
    else
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN "{:name=>:id}" to id;
      SQL
    end
  end

  down do
    if database_type == :mysql
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN id to `{:name=>:id}`;
      SQL
    else
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN id to "{:name=>:id}";
      SQL
    end
  end
end
