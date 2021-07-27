Sequel.migration do
  change do
    create_table :spaces_supporters do
      primary_key :id, name: :spaces_supporters_pk
      String :role_guid, size: 255
      Integer :space_id, null: false
      Integer :user_id, null: false
      Timestamp :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      Timestamp :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      foreign_key [:space_id], :spaces, name: :spaces_supporters_space_fk
      foreign_key [:user_id], :users, name: :spaces_supporters_user_fk

      index [:space_id, :user_id], unique: true, name: :spaces_supporters_user_space_index
      index :role_guid, name: :spaces_supporters_role_guid_index
      index :created_at, name: :spaces_supporters_created_at_index
      index :updated_at, name: :spaces_supporters_updated_at_index
    end
  end
end
