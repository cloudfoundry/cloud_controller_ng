require 'date'
Sequel.migration do
  up do
    if self.class.name.match?(/mysql/i)
      run <<-SQL.squish
        ALTER TABLE asg_timestamps MODIFY last_update TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
      SQL
    end
  end

  down do
    if self.class.name.match?(/mysql/i)
      run <<-SQL.squish
        ALTER TABLE asg_timestamps MODIFY last_update TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      SQL
    end
  end
end
