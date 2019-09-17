Sequel.migration do
  change do
    create_table :revision_sidecars do
      VCAP::Migration.common(self)
      String :name,    size: 255, null: false
      String :command, size: 4096, null: false
      String :revision_guid, size: 255, null: false
      Integer :memory, default: nil
      foreign_key [:revision_guid], :revisions, key: :guid, name: :fk_sidecar_revision_guid
      index [:revision_guid], name: :fk_sidecar_revision_guid_index
    end

    create_table :revision_sidecar_process_types do
      VCAP::Migration.common(self)
      String :type, size: 255, null: false
      String :revision_sidecar_guid, size: 255, null: false
      foreign_key [:revision_sidecar_guid], :revision_sidecars, key: :guid, name: :fk_revision_sidecar_proc_type_sidecar_guid
      index [:revision_sidecar_guid], name: :fk_revision_sidecar_proc_type_sidecar_guid_index
    end
  end
end
