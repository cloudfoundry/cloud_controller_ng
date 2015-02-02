Sequel.migration do
  change do
    create_table :service_instance_operations do
      VCAP::Migration.common(self)
      Integer :service_instance_id
      index :service_instance_id, name: :svc_instance_id_index
      foreign_key [:service_instance_id], :service_instances, name: :fk_svc_inst_op_svc_instance_id

      String :type
      String :state
      String :description
    end

    alter_table :service_instances do
      drop_column :state
      drop_column :state_description
    end

    rename_index(:service_instance_operations, :created_at, name: :svc_inst_op_created_at_index)
    rename_index(:service_instance_operations, :updated_at, name: :svc_inst_op_updated_at_index)
    rename_index(:service_instance_operations, :guid, name: :svc_inst_op_guid_index)
    rename_index(:service_instance_operations, :id, name: :svc_inst_op_id_index)
  end
end
