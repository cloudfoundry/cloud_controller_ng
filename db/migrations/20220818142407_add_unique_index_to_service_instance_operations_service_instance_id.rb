Sequel.migration do
  up do
    # Remove duplicate service_instance_operations.service_instance_id to prepare for adding a uniqueness constraint

    dup_groups = self[:service_instance_operations].exclude(service_instance_id: nil).
                 select(:service_instance_id).
                 group_by(:service_instance_id).
                 having { count.function.* > 1 }

    dup_groups.each do |group|
      sorted_ids = self[:service_instance_operations].
                   select(:id).
                   where(service_instance_id: group[:service_instance_id]).
                   map(&:values).
                   flatten.
                   sort
      ids_to_remove = sorted_ids

      same_si_same_updated_at_take_max_id = self[:service_instance_operations].
                                            select(Sequel.function(:max, :id)).
                                            where(service_instance_id: group[:service_instance_id]).
                                            group_by(:updated_at, :service_instance_id).
                                            having { count.function.* > 1 }.
                                            map(&:values).
                                            flatten.
                                            sort

      same_si_same_updated_at_take_si_ids = self[:service_instance_operations].exclude(id: same_si_same_updated_at_take_max_id).
                                            select(:service_instance_id).
                                            where(service_instance_id: group[:service_instance_id]).
                                            group_by(:updated_at, :service_instance_id).
                                            having { count.function.* > 1 }.
                                            map(&:values).
                                            flatten.
                                            sort

      same_si_same_updated_at_take_date = self[:service_instance_operations].exclude(id: same_si_same_updated_at_take_max_id).
                                          select(:updated_at).
                                          where(service_instance_id: group[:service_instance_id]).
                                          group_by(:updated_at, :service_instance_id).
                                          having { count.function.* > 1 }.
                                          map(&:values).
                                          flatten.
                                          sort

      id_for_same_si_same_updated_at = self[:service_instance_operations].
                                       select(:id).
                                       where(updated_at: same_si_same_updated_at_take_date, service_instance_id: same_si_same_updated_at_take_si_ids).
                                       map(&:values).
                                       flatten.
                                       sort

      same_si_diff_updated_at_take_max_updated_at = self[:service_instance_operations].exclude(id: id_for_same_si_same_updated_at).
                                                    select(Sequel.function(:max, :updated_at)).
                                                    where(service_instance_id: group[:service_instance_id]).
                                                    group_by(:service_instance_id).
                                                    having { count.function.* > 1 }.
                                                    map(&:values).
                                                    flatten.
                                                    sort

      id_for_same_si_diff_updated_at = self[:service_instance_operations].
                                       select(:id).
                                       where(updated_at: same_si_diff_updated_at_take_max_updated_at).
                                       map(&:values).
                                       flatten.
                                       sort

      ids_to_keep = same_si_same_updated_at_take_max_id + id_for_same_si_diff_updated_at

      self[:service_instance_operations].exclude(id: ids_to_keep).
        where(id: ids_to_remove).delete
    end

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
