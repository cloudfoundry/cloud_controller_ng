module VCAP::CloudController
  class SecurityGroupApply
    class Error < ::StandardError
    end

    class << self
      def apply_running(security_group, message, readable_space_guids)
        apply(security_group, message, readable_space_guids, :running)
      end

      def apply_staging(security_group, message, readable_space_guids)
        apply(security_group, message, readable_space_guids, :staging)
      end

      private

      def apply(security_group, message, readable_space_guids, staging_or_running)
        spaces = valid_spaces(message.space_guids, readable_space_guids)

        if staging_or_running == :running
          SecurityGroup.db.transaction do
            spaces.each { |space| security_group.add_space(space) }
          end
        elsif staging_or_running == :staging
          SecurityGroup.db.transaction do
            spaces.each { |space| security_group.add_staging_space(space) }
          end
        end
      rescue Sequel::ValidationFailed => e
        error!(e.message)
      end

      def valid_spaces(requested_space_guids, readable_space_guids)
        existing_spaces = Space.where(guid: requested_space_guids).all
        existing_space_guids = existing_spaces.map(&:guid)

        nonexistent_space_guids = requested_space_guids - existing_space_guids
        unreadable_space_guids = existing_space_guids - readable_space_guids

        invalid_space_guids = nonexistent_space_guids + unreadable_space_guids
        error!("Spaces with guids #{invalid_space_guids} do not exist, or you do not have access to them.") if invalid_space_guids.any?

        existing_spaces
      end

      def error!(message)
        raise Error.new(message)
      end
    end
  end
end
