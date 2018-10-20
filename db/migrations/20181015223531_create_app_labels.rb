Sequel.migration do
  change do
    create_table(:app_labels) do
      VCAP::Migration.common(self)

      String :app_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:app_guid], :apps, key: :guid, name: :fk_app_labels_app_guid
      index [:app_guid], name: :fk_app_labels_app_guid_index
      index [:key_prefix, :key_name, :value], name: :app_labels_compound_index
    end
  end
end
