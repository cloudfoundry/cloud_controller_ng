Sequel.migration do
  up do
    alter_table(:v3_droplets) do
      drop_column :lifecycle
    end
  end

  down do
    if Sequel::Model.db.database_type == :mssql
      add_column :v3_droplets, :lifecycle, String, size: :max, null: true
    else
      add_column :v3_droplets, :lifecycle, String, text: true, null: true
    end
  end
end
