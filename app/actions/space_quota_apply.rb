module VCAP::CloudController
  class SpaceQuotaApply
    class Error < ::StandardError
    end

    def apply(space_quota, message, readable_space_guids)
      spaces = valid_spaces(message.space_guids, readable_space_guids, space_quota.organization_id)

      SpaceQuotaDefinition.db.transaction do
        spaces.each { |space| space_quota.add_space(space) }
      end
    rescue Sequel::ValidationFailed => e
      error!(e.message)
    end

    private

    def valid_spaces(requested_space_guids, readable_space_guids, space_quota_org_id)
      existing_spaces = Space.where(guid: requested_space_guids).all
      existing_space_guids = existing_spaces.map(&:guid)

      nonexistent_space_guids = requested_space_guids - existing_space_guids
      unreadable_space_guids = existing_space_guids - readable_space_guids

      invalid_space_guids =  nonexistent_space_guids + unreadable_space_guids
      error!("Spaces with guids #{invalid_space_guids} do not exist, or you do not have access to them.") if invalid_space_guids.any?

      outside_spaces = existing_spaces.reject { |space| space.organization_id == space_quota_org_id }
      error!('Space quotas cannot be applied outside of their owning organization.') if outside_spaces.any?

      existing_spaces
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
