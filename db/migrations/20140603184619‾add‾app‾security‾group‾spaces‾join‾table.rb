Sequel.migration do
  change do
    create_table :app_security_groups_spaces do
      Integer :app_security_group_id, null: false
      foreign_key [:app_security_group_id], :app_security_groups, name: :fk_app_security_group_id

      Integer :space_id, null: false
      foreign_key [:space_id], :spaces, name: :fk_space_id

      index [:app_security_group_id, :space_id], unique: true, name: 'asgs_spaces_ids'
    end
  end
end
