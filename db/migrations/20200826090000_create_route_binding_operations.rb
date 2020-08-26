Sequel.migration do
  change do
    create_table :route_binding_operations do
      VCAP::Migration.timestamps(self, :route_binding_operations)

      Integer :route_binding_id
      String :state, size: 255, null: false
      String :type, size: 255, null: false
      String :description, size: 10000
      String :broker_provided_operation, size: 10000

      index :route_binding_id, name: :route_binding_id_index, unique: true
      primary_key :id, name: :id
      foreign_key [:route_binding_id], :route_bindings, name: :fk_route_binding_op_route_binding_id, on_delete: :cascade
    end
  end
end
