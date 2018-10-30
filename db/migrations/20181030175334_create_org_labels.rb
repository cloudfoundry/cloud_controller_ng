Sequel.migration do
  change do
    create_table(:org_labels) do
      VCAP::Migration.common(self)

      String :org_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:org_guid], :organizations, key: :guid, name: :fk_org_labels_org_guid
      index [:org_guid], name: :fk_org_labels_org_guid_index
      index [:key_prefix, :key_name, :value], name: :org_labels_compound_index
    end
  end
end
