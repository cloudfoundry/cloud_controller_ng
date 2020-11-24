Sequel.migration do
  change do
    create_table :service_key_operations do
      VCAP::Migration.timestamps(self, :service_key_operations)

      Integer :service_key_id
      String :state, size: 255, null: false
      String :type, size: 255, null: false
      String :description, size: 10000
      String :broker_provided_operation, size: 10000

      index :service_key_id, name: :svc_key_id_index, unique: true
      primary_key :id, name: :id
      foreign_key [:service_key_id], :service_keys, name: :fk_svc_key_op_svc_key_id, on_delete: :cascade
    end
  end
end
