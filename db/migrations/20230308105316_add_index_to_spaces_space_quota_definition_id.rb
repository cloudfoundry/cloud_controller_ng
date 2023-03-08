Sequel.migration do
  change do
    alter_table :spaces do
      add_index :space_quota_definition_id, name: :spaces_space_quota_definition_id_index
    end
  end
end
