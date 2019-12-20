Sequel.migration do
  up do
    unless self[:organizations_billing_managers].columns.include?(:role_guid)
      alter_table :organizations_billing_managers do
        add_column :role_guid, String, size: 255
        add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_index :role_guid, name: :organizations_billing_managers_role_guid_index
        add_index :created_at, name: :organizations_billing_managers_created_at_index
        add_index :updated_at, name: :organizations_billing_managers_updated_at_index
      end
    end
  end

  down do
    alter_table :organizations_billing_managers do
      drop_index :updated_at, name: :organizations_billing_managers_role_guid_index
      drop_index :created_at, name: :organizations_billing_managers_created_at_index
      drop_index :role_guid, name: :organizations_billing_managers_updated_at_index
      drop_column :updated_at
      drop_column :created_at
      drop_column :role_guid
    end
  end
end
