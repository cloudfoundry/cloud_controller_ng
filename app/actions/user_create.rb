module VCAP::CloudController
  class UserCreate
    class Error < StandardError
    end

    def create(message:)
      shadow_user = User.create_uaa_shadow_user(message.username, message.origin) if message.username && message.origin
      user_guid = shadow_user ? shadow_user['id'] : message.guid

      user = User.create(guid: user_guid)
      User.db.transaction do
        MetadataUpdate.update(user, message)
      end

      user
    rescue Sequel::ValidationFailed => e
      validation_error!(message, e)
    end

    private

    def validation_error!(message, error)
      error!("User with guid '#{message.guid}' already exists.") if message.guid && error.errors.on(:guid)&.any? { |e| [:unique].include?(e) }

      if !message.guid && error.errors.on(:guid)&.any? { |e| [:unique].include?(e) }
        error!("User with username '#{message.username}' and origin '#{message.origin}' already exists.")
      end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
