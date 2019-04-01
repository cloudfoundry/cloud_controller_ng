Sequel.migration do
  change do
    alter_table :service_brokers do
      add_column :salt, String
    end
  end
end
