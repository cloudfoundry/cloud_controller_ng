module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PENDING_STATE  = 'PROCESSING_UPLOAD'
    READY_STATE    = 'READY'
    FAILED_STATE   = 'FAILED'
    CREATED_STATE  = 'AWAITING_UPLOAD'
    PACKAGE_STATES = [CREATED_STATE, PENDING_STATE, READY_STATE, FAILED_STATE].map(&:freeze).freeze

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
    end

    def self.user_visible(user)
      dataset.where(Sequel.or([
        [:space_guid, user.spaces_dataset.select(:guid)],
        [:space_guid, user.managed_spaces_dataset.select(:guid)],
        [:space_guid, user.audited_spaces_dataset.select(:guid)],
        [:space_guid, user.managed_organizations_dataset.join(
          :spaces, spaces__organization_id: :organizations__id
        ).select(:spaces__guid)],
      ]))
    end
  end
end
