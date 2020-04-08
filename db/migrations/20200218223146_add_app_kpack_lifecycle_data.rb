Sequel.migration do
  change do
    alter_table :kpack_lifecycle_data do
      add_column :app_guid, String, size: 255, null: true
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_kpack_lifecycle_app_guid

      set_column_allow_null :build_guid
    end
  end
end
