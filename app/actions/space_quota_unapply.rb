module VCAP::CloudController
  class SpaceQuotaUnapply
    class Error < ::StandardError
    end

    def self.unapply(space_quota, space)
      SpaceQuotaDefinition.db.transaction do
        space_quota.remove_space(space)
      end
    rescue Sequel::ValidationFailed => e
      raise Error.new(e.message)
    end
  end
end
