Sequel.migration do
  up do
    # rubocop:disable Migration/IncludeStringSize
    add_column :buildpack_lifecycle_data, :encrypted_credentials_json, String, if_not_exists: true
    # rubocop:enable Migration/IncludeStringSize
    add_column :buildpack_lifecycle_data, :encrypted_credentials_json_salt, String, size: 255, if_not_exists: true
    # encryption_key_label and encryption_iterations already exist (added by earlier migrations for buildpack_url encryption)
  end

  down do
    drop_column :buildpack_lifecycle_data, :encrypted_credentials_json, if_exists: true
    drop_column :buildpack_lifecycle_data, :encrypted_credentials_json_salt, if_exists: true
  end
end
