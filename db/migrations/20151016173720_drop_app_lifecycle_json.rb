Sequel.migration do
  up do
    drop_column :apps_v3, :lifecycle
  end

  down do
    alter_table(:app_v3) do
      if Sequel::Model.db.database_type == :mssql
        add_column :lifecycle, String, size: :max, null: true
      else
        add_column :lifecycle, String, text: true, null: true
      end
    end
  end
end
