Sequel.migration do
  change do
    alter_table :routes do
      drop_column :service_instance_id
    end
  end
end
