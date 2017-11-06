Sequel.migration do
  up do
    transaction do
      run <<-SQL
        UPDATE processes SET health_check_timeout=NULL WHERE health_check_timeout='0';
      SQL
    end
  end
end
