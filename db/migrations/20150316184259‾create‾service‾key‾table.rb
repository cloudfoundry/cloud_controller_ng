Sequel.migration do
  change do
    create_table(:service_keys) do
      VCAP::Migration.common(self, :sk)
      String :name, null: false
      String :salt
      String :credentials, null: false, size: 2048
      Integer :service_instance_id, null: false
      foreign_key [:service_instance_id], :service_instances, name: :fk_svc_key_svc_instance_id
      index [:name, :service_instance_id], unique: true, name: :svc_key_name_instance_id_index
    end
  end
end
