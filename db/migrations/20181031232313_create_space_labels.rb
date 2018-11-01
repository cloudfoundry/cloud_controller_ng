Sequel.migration do
  change do
    create_table(:space_labels) do
      VCAP::Migration.common(self)

      String :space_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:space_guid], :spaces, key: :guid, name: :fk_space_labels_space_guid
      index [:space_guid], name: :fk_space_labels_space_guid_index
      index [:key_prefix, :key_name, :value], name: :space_labels_compound_index
    end
  end
end
