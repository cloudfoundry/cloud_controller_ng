Sequel.migration do
  change do
    create_table :staging_security_groups_spaces do
      Integer :staging_security_group_id, null: false
      foreign_key [:staging_security_group_id], :security_groups, name: :fk_staging_security_group_id

      Integer :staging_space_id, null: false
      foreign_key [:staging_space_id], :spaces, name: :fk_staging_space_id

      index [:staging_security_group_id, :staging_space_id], unique: true, name: 'staging_security_groups_spaces_ids'
    end
  end
end
