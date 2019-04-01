Sequel.migration do
  change do
    add_column :builds, :created_by_user_guid, :text, null: true
    add_column :builds, :created_by_user_name, :text, null: true
    add_column :builds, :created_by_user_email, :text, null: true
  end
end
