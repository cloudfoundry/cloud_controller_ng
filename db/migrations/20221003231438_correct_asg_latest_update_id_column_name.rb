Sequel.migration do
  up do
    if database_type == :mysql
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN `{:name=>:id}` to id;
      SQL.squish
    else
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN "{:name=>:id}" to id;
      SQL.squish
    end
  end

  down do
    if database_type == :mysql
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN id to `{:name=>:id}`;
      SQL.squish
    else
      run <<-SQL
        ALTER TABLE asg_timestamps RENAME COLUMN id to "{:name=>:id}";
      SQL.squish
    end
  end
end
