Sequel.migration do
  up do
    drop_column :package_docker_data, :encrypted_user
    drop_column :package_docker_data, :user_salt
    drop_column :package_docker_data, :encrypted_password
    drop_column :package_docker_data, :password_salt
    drop_column :package_docker_data, :email_salt
    drop_column :package_docker_data, :encrypted_login_server
    drop_column :package_docker_data, :login_server_salt
    drop_column :package_docker_data, :store_image
  end

  down do
    add_column :package_docker_data, :encrypted_user, String
    add_column :package_docker_data, :user_salt, String
    add_column :package_docker_data, :encrypted_password, String
    add_column :package_docker_data, :password_salt, String
    add_column :package_docker_data, :email_salt, String
    add_column :package_docker_data, :encrypted_login_server, String
    add_column :package_docker_data, :login_server_salt, String
    add_column :package_docker_data, :store_image, TrueClass, default: false
  end
end
