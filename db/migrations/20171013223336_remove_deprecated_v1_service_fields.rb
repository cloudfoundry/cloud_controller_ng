Sequel.migration do
  up do
    alter_table :services do
      drop_column :provider
      drop_column :url
      drop_column :version
    end
  end

  down do
    alter_table :services do
      add_column :provider, String, null: false, case_insensitive: true
      add_column :url, String, null: false
      add_column :version, String, null: false
    end
  end
end
