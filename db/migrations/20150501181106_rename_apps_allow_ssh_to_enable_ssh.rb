Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      rename_column :apps, :allow_ssh, 'ENABLE_SSH'
    else
      rename_column :apps, :allow_ssh, :enable_ssh
    end
  end
end
