Sequel.migration do
  up do
    # Remove duplicate service_instance_operations.service_instance_id to prepare for adding a uniqueness constraint
    max_updated_at_group = self[:service_instance_operations].
                           select(Sequel.function(:max, :updated_at)).
                           group_by(:service_instance_id).
                           having { count.function.* >= 1 }
    service_instance_id_group = self[:service_instance_operations].
                                select(:service_instance_id).
                                group_by(:service_instance_id).
                                having { count.function.* >= 1 }
    self[:service_instance_operations].exclude(id: self[:service_instance_operations].select(:id).
      where { Sequel.&(Sequel.|({ service_instance_id: service_instance_id_group }, { service_instance_id: nil }),
                       { updated_at: max_updated_at_group })
      }).each do |row|
      self[:service_instance_operations].where(id: row[:id]).delete
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
      add_foreign_key [:service_instance_id], :service_instances, key: :id, name: :fk_svc_inst_op_svc_instance_id
    end
  end
end
