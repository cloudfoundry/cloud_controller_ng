Sequel.migration do
  change do
    alter_table :security_groups_spaces do
      add_index :space_id, name: :security_groups_spaces_space_id_index
    end
  end
end
