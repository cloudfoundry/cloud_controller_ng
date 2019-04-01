Sequel.migration do
  change do
    create_table :sidecars do
      VCAP::Migration.common(self)
      String :name,    size: 255, null: false
      String :command, size: 4096, null: false
      String :app_guid, size: 255, null: false
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_sidecar_app_guid
      index [:app_guid], name: :fk_sidecar_app_guid_index
    end

    create_table :sidecar_process_types do
      VCAP::Migration.common(self)
      String :name,         size: 255, null: false
      String :sidecar_guid, size: 255, null: false
      foreign_key [:sidecar_guid], :sidecars, key: :guid, name: :fk_sidecar_proc_type_sidecar_guid
      index [:sidecar_guid], name: :fk_sidecar_proc_type_sidecar_guid_index
    end
  end
end
