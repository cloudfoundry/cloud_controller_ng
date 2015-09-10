Sequel.migration do
  change do
    alter_table :routes do
      add_foreign_key :service_instance_id, :service_instances
    end
  end
end
