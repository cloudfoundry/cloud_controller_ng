Sequel.migration do
  no_transaction # adding an index concurrently cannot be done within a transaction

  up do
    if database_type == :mysql && server_version < 80_000 # MySQL versions < 8 cannot drop unique constraints directly
      alter_table(:service_bindings) do
        # rubocop:disable Sequel/ConcurrentIndex
        if @db.indexes(:service_bindings).key?(:unique_service_binding_service_instance_guid_app_guid)
          drop_index %i[service_instance_guid app_guid],
                     name: :unique_service_binding_service_instance_guid_app_guid
        end
        drop_index %i[app_guid name], name: :unique_service_binding_app_guid_name if @db.indexes(:service_bindings).key?(:unique_service_binding_app_guid_name)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    else
      alter_table(:service_bindings) do
        drop_constraint(:unique_service_binding_service_instance_guid_app_guid) if @db.indexes(:service_bindings).key?(:unique_service_binding_service_instance_guid_app_guid)
        drop_constraint(:unique_service_binding_app_guid_name) if @db.indexes(:service_bindings).key?(:unique_service_binding_app_guid_name)
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, concurrently: true, if_not_exists: true
        add_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, concurrently: true, if_not_exists: true
      end
    elsif database_type == :mysql
      alter_table(:service_bindings) do
        # rubocop:disable Sequel/ConcurrentIndex
        unless @db.indexes(:service_bindings).key?(:service_bindings_app_guid_service_instance_guid_index)
          add_index %i[app_guid service_instance_guid],
                    name: :service_bindings_app_guid_service_instance_guid_index
        end
        add_index %i[app_guid name], name: :service_bindings_app_guid_name_index unless @db.indexes(:service_bindings).key?(:service_bindings_app_guid_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    alter_table(:service_bindings) do
      if @db.indexes(:service_bindings)[:unique_service_binding_service_instance_guid_app_guid].blank?
        add_unique_constraint %i[service_instance_guid app_guid],
                              name: :unique_service_binding_service_instance_guid_app_guid
      end
    end
    alter_table(:service_bindings) do
      add_unique_constraint %i[app_guid name], name: :unique_service_binding_app_guid_name if @db.indexes(:service_bindings)[:unique_service_binding_app_guid_name].blank?
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, concurrently: true, if_exists: true
        drop_index :service_bindings, %i[app_guid name], name: :service_bindings_app_guid_name_index, concurrently: true, if_exists: true
      end
    elsif database_type == :mysql
      alter_table(:service_bindings) do
        # rubocop:disable Sequel/ConcurrentIndex
        if @db.indexes(:service_bindings).key?(:service_bindings_app_guid_service_instance_guid_index)
          drop_index %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index
        end
        drop_index %i[app_guid name], name: :service_bindings_app_guid_name_index if @db.indexes(:service_bindings).key?(:service_bindings_app_guid_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
