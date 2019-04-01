Sequel.migration do
  change do
    alter_table :service_brokers do
      add_foreign_key :space_id, :spaces
    end
  end
end
