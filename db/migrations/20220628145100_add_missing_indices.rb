Sequel.migration do
  up do
    alter_table :processes do
      add_index :revision_guid, name: :processes_revision_guid_index
    end

    alter_table :deployments do
      add_index :revision_guid, name: :deployments_revision_guid_index
    end

    alter_table :sidecar_process_types do
      add_index :app_guid, name: :sidecar_process_types_app_guid_index
    end
  end

  down do
    alter_table :processes do
      drop_index :revision_guid, name: :processes_revision_guid_index
    end

    alter_table :deployments do
      drop_index :revision_guid, name: :deployments_revision_guid_index
    end

    alter_table :sidecar_process_types do
      drop_index :app_guid, name: :sidecar_process_types_app_guid_index
    end
  end
end
