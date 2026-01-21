require 'repositories/space_quota_event_repository'

module VCAP::CloudController
  class SpaceQuotaUnapply
    class Error < ::StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def unapply(space_quota, space)
      SpaceQuotaDefinition.db.transaction do
        space_quota.remove_space(space)
        Repositories::SpaceQuotaEventRepository.new.record_space_quota_remove(space_quota, space, @user_audit_info)
      end
    rescue Sequel::ValidationFailed => e
      raise Error.new(e.message)
    end
  end
end
