require "securerandom"

module VCAP::CloudController::Models
  class Task < Sequel::Model
    many_to_one :app

    export_attributes :app_guid, :secure_token
    import_attributes :app_guid

    def space
      app.space
    end

    def before_save
      self.secure_token ||= SecureRandom.urlsafe_base64
    end

    def after_commit
      task_client.start_task(self)
    end

    def after_destroy
      task_client.stop_task(self)
    end

    def secure_token=(token)
      generate_salt

      super(VCAP::CloudController::Encryptor.encrypt(token, salt))
    end

    def secure_token
      VCAP::CloudController::Encryptor.decrypt(super, salt)
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :app => App.user_visible(user))
    end

    private

    def task_client
      CloudController::DependencyLocator.instance.task_client
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt.freeze
    end
  end
end
