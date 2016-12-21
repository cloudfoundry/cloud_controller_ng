Sequel.migration do
  change do
    create_table :package_docker_data do
      VCAP::Migration.common(self, :package_docker_data)

      String :image

      String :encrypted_user
      String :user_salt

      String :encrypted_password
      String :password_salt

      String :encrypted_email
      String :email_salt

      String :encrypted_login_server
      String :login_server_salt

      TrueClass :store_image, default: false

      String :package_guid
      index :package_guid, name: :package_docker_data_package_guid
    end
  end
end
