Sequel.migration do
  change do
    rename_table(:app_security_groups, :security_groups)

    alter_table(:security_groups) do
      drop_index :guid, name: 'asg_guid_index'
      add_index :guid, name: 'sg_guid_index'

      drop_index :created_at, name: 'asg_created_at_index'
      add_index :created_at, name: 'sg_created_at_index'

      drop_index :updated_at, name: 'asg_updated_at_index'
      add_index :updated_at, name: 'sg_updated_at_index'

      drop_index :staging_default, name: 'asgs_staging_default'
      add_index :staging_default, name: 'sgs_staging_default_index'

      drop_index :running_default, name: 'asgs_running_default'
      add_index :running_default, name: 'sgs_running_default_index'

      drop_index :name, name: 'asgs_name'
      add_index :name, name: 'sg_name_index'
    end

    rename_table(:app_security_groups_spaces, :security_groups_spaces)

    alter_table(:security_groups_spaces) do
      drop_foreign_key [:app_security_group_id], name: :fk_app_security_group_id
      drop_index [:app_security_group_id, :space_id], name: 'asgs_spaces_ids'

      if Sequel::Model.db.database_type == :mssql
        rename_column(:app_security_group_id, 'SECURITY_GROUP_ID')
      else
        rename_column(:app_security_group_id, :security_group_id)
      end

      add_foreign_key [:security_group_id], :security_groups, name: :fk_security_group_id
      add_index [:security_group_id, :space_id], name: 'sgs_spaces_ids'
    end
  end
end
