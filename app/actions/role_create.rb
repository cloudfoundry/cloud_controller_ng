require 'models/helpers/role_types'

module VCAP::CloudController
  class RoleCreate
    class Error < StandardError
    end

    class << self
      def create(message:)
        user_guid = message.user_guid
        space_guid = message.space_guid
        user = User.find(guid: user_guid)
        space = Space.find(guid: space_guid)

        case message.type
        when RoleTypes::SPACE_AUDITOR
          create_space_auditor(user, space)
        when RoleTypes::SPACE_DEVELOPER
          create_space_developer(user, space)
        when RoleTypes::SPACE_MANAGER
          create_space_manager(user, space)
        else
          error!("Role type '#{message.type}' is invalid.")
        end
      rescue Sequel::ValidationFailed => e
        validation_error!(message, e, user, space)
      end

      private

      def create_space_auditor(user, space)
        SpaceAuditor.create(user_id: user.id, space_id: space.id)
      end

      def create_space_developer(user, space)
        SpaceDeveloper.create(user_id: user.id, space_id: space.id)
      end

      def create_space_manager(user, space)
        SpaceManager.create(user_id: user.id, space_id: space.id)
      end

      def validation_error!(message, error, user, space)
        if error.errors.on([:space_id, :user_id])&.any? { |e| [:unique].include?(e) }
          error!("User '#{user.presentation_name}' already has '#{message.type}' role in space '#{space.name}'.")
        end

        error!(error.message)
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
