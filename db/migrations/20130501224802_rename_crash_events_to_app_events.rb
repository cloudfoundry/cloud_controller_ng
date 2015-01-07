Sequel.migration do
  change do
    alter_table :crash_events do
      drop_constraint :fk_crash_events_app_id, type: :foreign_key
      add_foreign_key :app_id, :apps, name: :fk_app_events_app_id

      drop_index :app_id
      add_index :app_id, name: :app_events_app_id_index

      drop_index :created_at
      add_index :created_at, name: :app_events_created_at_index

      drop_index :updated_at
      add_index :updated_at, name: :app_events_updated_at_index

      drop_index :guid
      add_index :guid, name: :app_events_guid_index, unique: true
    end

    rename_table(:crash_events, :app_events)
  end
end
