module VCAP::CloudController
  class SpaceQuotaApply
    class Error < ::StandardError
    end

    def apply(space_quota, message)
      SpaceQuotaDefinition.db.transaction do
        spaces = valid_spaces(message.space_guids)
        spaces.each { |space| space_quota.add_space(space) }
      end
    rescue Sequel::ValidationFailed => e
      error!(e.message)
    end

    private

    def valid_spaces(space_guids)
      spaces = Space.where(guid: space_guids).all
      return spaces if spaces.length == space_guids.length

      invalid_space_guids = space_guids - spaces.map(&:guid)
      error!("Spaces with guids #{invalid_space_guids} do not exist, or you do not have access to them.")
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
