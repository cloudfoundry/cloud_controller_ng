Sequel.migration do
  up do
    if self.class.name =~ /mysql/i
      self[:events].truncate
      run('ALTER TABLE events CHANGE updated_at updated_at TIMESTAMP NULL DEFAULT NULL')
      run('ALTER TABLE events CHANGE created_at created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;')
    elsif Sequel::Model.db.database_type == :mssql
      run('ALTER TABLE events ADD DEFAULT NULL FOR updated_at')
    end
  end

  down do
    if self.class.name =~ /mysql/i
      self[:events].truncate
      run('ALTER TABLE events CHANGE created_at created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;')
    end
  end
end
