require 'repositories/space_quota_event_repository'

module VCAP::CloudController
  class SpaceQuotaDeleteAction
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(space_quotas)
      space_quotas.each do |space_quota|
        SpaceQuotaDefinition.db.transaction do
          Repositories::SpaceQuotaEventRepository.new.record_space_quota_delete(space_quota, @user_audit_info)
          space_quota.destroy
        end
      end
      []
    end
  end
end
