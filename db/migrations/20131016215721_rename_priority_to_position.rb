Sequel.migration do
  change do
    alter_table :buildpacks do
      if Sequel::Model.db.database_type == :mssql
        rename_column :priority, 'POSITION'
      else
        rename_column :priority, :position
      end
    end
  end
end
