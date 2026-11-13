Sequel.migration do
  up do
    add_column :buildpack_lifecycle_data, :encrypted_credentials_json, String, size: 16_000, if_not_exists: true
    add_column :buildpack_lifecycle_data, :encrypted_credentials_json_salt, String, size: 255, if_not_exists: true
    # encryption_key_label and encryption_iterations already exist (added by earlier migrations for buildpack_url encryption)

    # Existing CNB credentials column was created unsized (varchar(255) on MySQL),
    # too small for an encrypted, base64-encoded multi-host credentials map. Grow it to match.
    set_column_type :cnb_lifecycle_data, :encrypted_registry_credentials_json, String, size: 16_000
  end

  down do
    drop_column :buildpack_lifecycle_data, :encrypted_credentials_json, if_exists: true
    drop_column :buildpack_lifecycle_data, :encrypted_credentials_json_salt, if_exists: true

    set_column_type :cnb_lifecycle_data, :encrypted_registry_credentials_json, String, size: 255
  end
end
