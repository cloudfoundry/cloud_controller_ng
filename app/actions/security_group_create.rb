module VCAP::CloudController
  class SecurityGroupCreate
    MYSQL_INVALID_VALUE_ERROR = 1366

    class Error < ::StandardError
    end

    class << self
      def create(message)
        security_group = nil

        SecurityGroup.db.transaction do
          security_group = SecurityGroup.create(
            name: message.name,
            rules: message.rules || [],
            staging_default: message.staging || false,
            running_default: message.running || false,
          )
          AsgLatestUpdate.renew

          staging_spaces = valid_spaces(message.staging_space_guids)
          staging_spaces.each { |space| security_group.add_staging_space(space) }

          running_spaces = valid_spaces(message.running_space_guids)
          running_spaces.each { |space| security_group.add_space(space) }
        end

        security_group
      rescue Sequel::ValidationFailed => e
        validation_error!(e, message)
      rescue Sequel::DatabaseError => e
        invalid_value_error!(e)
      end

      private

      def validation_error!(error, message)
        if error.errors.on(:name)&.include?(:unique)
          error!("Security group with name '#{message.name}' already exists.")
        end

        error!(error.message)
      end

      def invalid_value_error!(error)
        if error.wrapped_exception.is_a?(Mysql2::Error) && error.wrapped_exception.error_number == MYSQL_INVALID_VALUE_ERROR
          if /column.*name/ =~ error.message
            error!('Security group name contains invalid characters.')
          elsif /column.*rules/ =~ error.message
            error!('Security group rules contain invalid characters.')
          end
        end

        raise error
      end

      def error!(message)
        raise Error.new(message)
      end

      def valid_spaces(space_guids)
        spaces = Space.where(guid: space_guids).all
        return spaces if spaces.length == space_guids.length

        invalid_space_guids = space_guids - spaces.map(&:guid)
        error!("Spaces with guids #{invalid_space_guids} do not exist.")
      end
    end
  end
end
