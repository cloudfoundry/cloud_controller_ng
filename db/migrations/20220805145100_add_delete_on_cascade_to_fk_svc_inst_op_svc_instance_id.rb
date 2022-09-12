Sequel.migration do
  # Add DELETE CASCADE to foreign key fk_svc_inst_op_svc_instance_id to ensure that 'service instance operations'
  # are deleted together with the referenced 'service instance'.

  up do
    alter_table :service_instance_operations do
      drop_constraint :fk_svc_inst_op_svc_instance_id, type: :foreign_key
      add_foreign_key [:service_instance_id], :service_instances, key: :id, name: :fk_svc_inst_op_svc_instance_id, on_delete: :cascade
    end
  end

  down do
    alter_table :service_instance_operations do
      drop_constraint :fk_svc_inst_op_svc_instance_id, type: :foreign_key
      add_foreign_key [:service_instance_id], :service_instances, key: :id, name: :fk_svc_inst_op_svc_instance_id
    end
  end
end
