Sequel.migration do
  change do
    create_table :service_instance_operations do
      VCAP::Migration.common(self, :svc_inst_op)
      Integer :service_instance_id
      index :service_instance_id, name: :svc_instance_id_index
      foreign_key [:service_instance_id], :service_instances, name: :fk_svc_inst_op_svc_instance_id

      String :type
      String :state
      String :description
    end
  end
end
