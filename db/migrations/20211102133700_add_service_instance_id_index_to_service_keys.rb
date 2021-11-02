Sequel.migration do
  up do
    alter_table :service_keys do
      add_index :service_instance_id, name: :sk_svc_instance_id_index
    end
  end

  down do
    alter_table :service_keys do
      drop_index :service_instance_id, name: :sk_svc_instance_id_index
    end
  end
end
