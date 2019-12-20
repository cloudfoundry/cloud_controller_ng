Sequel.migration do
  up do
    unless self[:organizations_users].columns.include?(:role_guid)
      alter_table :organizations_users do
        add_column :role_guid, String, size: 255
        add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_index :role_guid, name: :organizations_users_role_guid_index
        add_index :created_at, name: :organizations_users_created_at_index
        add_index :updated_at, name: :organizations_users_updated_at_index
      end
    end
  end

  down do
    alter_table :organizations_users do
      drop_index :updated_at, name: :organizations_users_role_guid_index
      drop_index :created_at, name: :organizations_users_created_at_index
      drop_index :role_guid, name: :organizations_users_updated_at_index
      drop_column :updated_at
      drop_column :created_at
      drop_column :role_guid
    end
  end
end
