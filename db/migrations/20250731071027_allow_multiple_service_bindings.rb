Sequel.migration do
  no_transaction # adding an index concurrently cannot be done within a transaction

  up do
    transaction do
      alter_table :service_bindings do
        drop_constraint :unique_service_binding_service_instance_guid_app_guid if @db.indexes(:service_bindings).include?(:unique_service_binding_service_instance_guid_app_guid)

        drop_constraint :unique_service_binding_app_guid_name if @db.indexes(:service_bindings).include?(:unique_service_binding_app_guid_name)
      end
    end

    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_not_exists: true, concurrently: true
    end
  end

  down do
    transaction do
      alter_table :service_bindings do
        unless @db.indexes(:service_bindings).include?(:unique_service_binding_service_instance_guid_app_guid)
          add_unique_constraint %i[service_instance_guid app_guid],
                                name: :unique_service_binding_service_instance_guid_app_guid
        end
        add_unique_constraint %i[app_guid name], name: :unique_service_binding_app_guid_name unless @db.indexes(:service_bindings).include?(:unique_service_binding_app_guid_name)
      end
    end

    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :service_bindings, %i[app_guid service_instance_guid], name: :service_bindings_app_guid_service_instance_guid_index, if_exists: true, concurrently: true
    end
  end
end
