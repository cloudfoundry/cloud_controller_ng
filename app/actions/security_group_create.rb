module VCAP::CloudController
  class SecurityGroupCreate
    class Error < ::StandardError
    end

    class << self
      def create(message)
        security_group = nil

        SecurityGroup.db.transaction do
          security_group = SecurityGroup.create(
            name: message.name,
            rules: message.rules,
            staging_default: message.staging || false,
            running_default: message.running || false,
          )
        end
        staging_spaces = valid_spaces(message.staging_space_guids)
        staging_spaces.each { |space| security_group.add_staging_space(space) }

        running_spaces = valid_spaces(message.running_space_guids)
        running_spaces.each { |space| security_group.add_space(space) }

        security_group
      rescue Sequel::ValidationFailed => e
        validation_error!(e, message)
      end

      private

      def validation_error!(error, message)
        if error.errors.on(:name)&.include?(:unique)
          error!("Security group with name '#{message.name}' already exists.")
        end

        error!(error.message)
      end

      def valid_spaces(space_guids)
        spaces = Space.where(guid: space_guids).all
        return spaces if spaces.length == space_guids.length

        invalid_space_guids = space_guids - spaces.map(&:guid)
        error!("Spaces with guids [#{invalid_space_guids}] do not exist.")
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
