Sequel.migration do
  up do
    run <<-SQL
      ALTER TABLE asg_timestamps RENAME COLUMN `{:name=>:id}` to `id`;
    SQL
  end

  down do
    run <<-SQL
      ALTER TABLE asg_timestamps RENAME COLUMN `id` to `{:name=>:id}`;
    SQL
  end
end
