Sequel.migration do
  up do
    # Remove duplicate service_instance_operations.service_instance_id to prepare for adding a uniqueness constraint

    dup_groups = self[:service_instance_operations].exclude(service_instance_id: nil).
                 select(:service_instance_id).
                 group_by(:service_instance_id).
                 having { count.function.* > 1 }

    dup_groups.each do |group|
      ids_to_remove = self[:service_instance_operations].
                      where(service_instance_id: group[:service_instance_id]).
                      order(Sequel.desc(:updated_at)).order_append(Sequel.desc(:id)).
                      offset(1).
                      select_map(:id)

      self[:service_instance_operations].where(id: ids_to_remove).delete
    end

    # for mysql the foreign_key constraint which references service_instance_id has to be removed before you can
    # delete the old index from service_instance_id
    alter_table :service_instance_operations do
      drop_constraint :fk_svc_inst_op_svc_instance_id, type: :foreign_key
      drop_index :service_instance_id, name: :svc_instance_id_index
      add_index :service_instance_id, name: :svc_inst_op_svc_instance_id_unique_index, unique: true
      add_foreign_key [:service_instance_id], :service_instances, key: :id, name: :fk_svc_inst_op_svc_instance_id, on_delete: :cascade
    end
  end
  down do
    alter_table :service_instance_operations do
      drop_constraint :fk_svc_inst_op_svc_instance_id, type: :foreign_key
      drop_index :service_instance_id, name: :svc_inst_op_svc_instance_id_unique_index
      add_index :service_instance_id, name: :svc_instance_id_index
      add_foreign_key [:service_instance_id], :service_instances, key: :id, name: :fk_svc_inst_op_svc_instance_id, on_delete: :cascade
    end
  end
end
