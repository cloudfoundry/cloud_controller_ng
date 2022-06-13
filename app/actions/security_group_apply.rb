module VCAP::CloudController
  class SecurityGroupApply
    class Error < ::StandardError
    end

    class << self
      def apply_running(security_group, message, visible_space_guids: [], all_spaces_visible: false)
        apply(security_group, message, :running, visible_space_guids, all_spaces_visible)
      end

      def apply_staging(security_group, message, visible_space_guids: [], all_spaces_visible: false)
        apply(security_group, message, :staging, visible_space_guids, all_spaces_visible)
      end

      private

      def apply(security_group, message, staging_or_running, visible_space_guids, all_spaces_visible)
        spaces = valid_spaces(message.space_guids, visible_space_guids, all_spaces_visible)

        if staging_or_running == :running
          SecurityGroup.db.transaction do
            spaces.each { |space| security_group.add_space(space) }
            AsgLatestUpdate.renew
          end
        elsif staging_or_running == :staging
          SecurityGroup.db.transaction do
            spaces.each { |space| security_group.add_staging_space(space) }
            AsgLatestUpdate.renew
          end
        end
      rescue Sequel::ValidationFailed => e
        error!(e.message)
      end

      def valid_spaces(requested_space_guids, visible_space_guids, all_spaces_visible)
        existing_spaces = Space.where(guid: requested_space_guids).all
        existing_space_guids = existing_spaces.map(&:guid)

        nonexistent_space_guids = requested_space_guids - existing_space_guids
        unreadable_space_guids = if all_spaces_visible
                                   []
                                 else
                                   existing_space_guids - visible_space_guids
                                 end

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
