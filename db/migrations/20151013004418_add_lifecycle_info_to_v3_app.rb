Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      add_column :apps_v3, :lifecycle, String, size: :max, null: true
    else
      add_column :apps_v3, :lifecycle, String, text: true, null: true
    end
  end

  down do
    alter_table(:app_v3) do
      drop_column :lifecycle
    end
  end
end
