Sequel.migration do
  change do
    alter_table :services do
      add_column :dashboard_client_id, String, :unique => true
    end
  end
end
