module VCAP::CloudController
  class PackageDockerDataModel < Sequel::Model(:package_docker_data)
    many_to_one :package,
      class: '::VCAP::CloudController::PackageModel',
      key: :package_guid,
      primary_key: :guid,
      without_guid_generation: true

    def credentials=(creds)
      creds = (creds.is_a?(Hash) ? OpenStruct.new(creds) : creds)
      self.user  = creds.user
      self.email = creds.email
      self.password = creds.password
      self.login_server = creds.login_server
    end

    def credentials
      return {} if no_credentials?
      {
        user: user,
        email: email,
        password: password,
        login_server: login_server,
      }
    end

    private

    def no_credentials?
      user.nil? && email.nil? && password.nil? && login_server.nil?
    end

    encrypt :user, salt: :user_salt, column: :encrypted_user
    encrypt :email, salt: :email_salt, column: :encrypted_email
    encrypt :password, salt: :password_salt, column: :encrypted_password
    encrypt :login_server, salt: :login_server_salt, column: :encrypted_login_server
  end
end
