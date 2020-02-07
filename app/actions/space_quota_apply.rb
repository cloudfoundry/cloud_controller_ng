module VCAP::CloudController
  class SpaceQuotaApply
    class Error < ::StandardError
    end

    def apply(space_quota, message)
      spaces = valid_spaces(message.space_guids, space_quota.organization_id)

      SpaceQuotaDefinition.db.transaction do
        spaces.each { |space| space_quota.add_space(space) }
      end
    rescue Sequel::ValidationFailed => e
      error!(e.message)
    end

    private

    def valid_spaces(requested_space_guids, space_quota_org_id)
      existing_spaces = Space.where(guid: requested_space_guids).all

      nonexistent_space_guids = requested_space_guids - existing_spaces.map(&:guid)
      error!("Spaces with guids #{nonexistent_space_guids} do not exist, or you do not have access to them.") if nonexistent_space_guids.any?

      invalid_spaces = existing_spaces.reject { |space| space.organization_id == space_quota_org_id }
      error!("Spaces with guids #{invalid_spaces.map(&:guid)} do not exist, or you do not have access to them.") if invalid_spaces.any?

      existing_spaces
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
