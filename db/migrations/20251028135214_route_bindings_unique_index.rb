Sequel.migration do
  up do
    transaction do
      # Remove duplicate entries if they exist
      duplicates = self[:route_bindings].
                   select(:route_id, :service_instance_id).
                   group(:route_id, :service_instance_id).
                   having { count(:id) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:route_bindings].
                        where(route_id: dup[:route_id], service_instance_id: dup[:service_instance_id]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)

        self[:route_bindings].where(id: ids_to_remove).delete
      end

      alter_table(:route_bindings) do
        # Cannot add unique constraint concurrently as it requires a transaction
        # rubocop:disable Sequel/ConcurrentIndex
        unless @db.indexes(:route_bindings).key?(:route_bindings_route_id_service_instance_id_index)
          add_index %i[route_id service_instance_id], unique: true,
                                                      name: :route_bindings_route_id_service_instance_id_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    # rubocop:disable Sequel/ConcurrentIndex
    if database_type == :mysql
      # MySQL replaces the auto generate 'route_id' index with 'route_bindings_route_id_service_instance_id_index' but does not re-create it during down migration
      alter_table(:route_bindings) { add_index :route_id, name: :route_id unless @db.indexes(:route_bindings).key?(:route_id) }
    end
    alter_table(:route_bindings) do
      if @db.indexes(:route_bindings).key?(:route_bindings_route_id_service_instance_id_index)
        drop_index %i[route_id service_instance_id], unique: true,
                                                     name: :route_bindings_route_id_service_instance_id_index
      end
    end
    # rubocop:enable Sequel/ConcurrentIndex
  end
end
