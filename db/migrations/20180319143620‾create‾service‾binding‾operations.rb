Sequel.migration do
  change do
    create_table :service_binding_operations do
      VCAP::Migration.timestamps(self, :service_binding_operations)

      Integer :service_binding_id
      String :state, size: 255, null: false
      String :type, size: 255, null: false
      String :description, size: 10000
      String :broker_provided_operation, size: 10000

      index :service_binding_id, name: :svc_binding_id_index, unique: true
      primary_key :id, name: :id
      foreign_key [:service_binding_id], :service_bindings, name: :fk_svc_binding_op_svc_binding_id, on_delete: :cascade
    end
  end
end
