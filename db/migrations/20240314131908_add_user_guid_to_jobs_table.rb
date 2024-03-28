Sequel.migration do
  up do
    alter_table :jobs do
      add_column :user_guid, String, size: 255
      add_index :user_guid, name: :jobs_user_guid_index
    end
  end

  down do
    alter_table :jobs do
      drop_index :user_guid, name: :jobs_user_guid_index
      drop_column :user_guid
    end
  end
end
