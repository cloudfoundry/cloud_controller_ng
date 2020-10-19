Sequel.migration do
  up do
    # We are assuming with this DB migration that the service_bindings table currently
    # has no duplicate rows, according to the unique constraint of
    # (service_instance_guid, app_guid). This migration will fail otherwise.
    #
    # Please manually remove duplicate entries from the database if
    # this migration is failing.

    alter_table :service_bindings do
      add_unique_constraint [:service_instance_guid, :app_guid], name: :unique_service_binding_service_instance_guid_app_guid
    end
  end

  down do
    alter_table :service_bindings do
      drop_constraint :unique_service_binding_service_instance_guid_app_guid
    end
  end
end
