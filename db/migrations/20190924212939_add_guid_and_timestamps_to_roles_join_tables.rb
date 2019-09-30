Sequel.migration do
  change do
    alter_table :spaces_auditors do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :spaces_auditors_guid_index
      add_index :created_at, name: :spaces_auditors_created_at_index
      add_index :updated_at, name: :spaces_auditors_updated_at_index
    end

    alter_table :spaces_managers do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :spaces_managers_guid_index
      add_index :created_at, name: :spaces_managers_created_at_index
      add_index :updated_at, name: :spaces_managers_updated_at_index
    end

    alter_table :spaces_developers do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :spaces_developers_guid_index
      add_index :created_at, name: :spaces_developers_created_at_index
      add_index :updated_at, name: :spaces_developers_updated_at_index
    end

    alter_table :organizations_users do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :organizations_users_guid_index
      add_index :created_at, name: :organizations_users_created_at_index
      add_index :updated_at, name: :organizations_users_updated_at_index
    end

    alter_table :organizations_managers do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :organizations_managers_guid_index
      add_index :created_at, name: :organizations_managers_created_at_index
      add_index :updated_at, name: :organizations_managers_updated_at_index
    end

    alter_table :organizations_auditors do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :organizations_auditors_guid_index
      add_index :created_at, name: :organizations_auditors_created_at_index
      add_index :updated_at, name: :organizations_auditors_updated_at_index
    end

    alter_table :organizations_billing_managers do
      add_column :guid, String, size: 255
      add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_column :updated_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
      add_index :guid, name: :organizations_billing_managers_guid_index
      add_index :created_at, name: :organizations_billing_managers_created_at_index
      add_index :updated_at, name: :organizations_billing_managers_updated_at_index
    end
  end
end
