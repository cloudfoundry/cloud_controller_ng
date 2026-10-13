Sequel.migration do
  up do
    # rubocop:disable Migration/IncludeStringSize
    add_column :buildpack_lifecycle_data, :encrypted_registry_credentials_json, String, if_not_exists: true
    # rubocop:enable Migration/IncludeStringSize
    add_column :buildpack_lifecycle_data, :encrypted_registry_credentials_json_salt, String, size: 255, if_not_exists: true
  end

  down do
    drop_column :buildpack_lifecycle_data, :encrypted_registry_credentials_json, if_exists: true
    drop_column :buildpack_lifecycle_data, :encrypted_registry_credentials_json_salt, if_exists: true
  end
end
