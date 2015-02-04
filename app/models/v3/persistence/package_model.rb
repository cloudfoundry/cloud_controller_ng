module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PACKAGE_STATES = [
      PENDING_STATE = 'PROCESSING_UPLOAD',
      READY_STATE   = 'READY',
      FAILED_STATE  = 'FAILED',
      CREATED_STATE = 'AWAITING_UPLOAD'
    ].map(&:freeze).freeze

    PACKAGE_TYPES = [
      BITS_TYPE   = 'bits',
      DOCKER_TYPE = 'docker'
    ].map(&:freeze).freeze

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
    end

    def self.user_visible(user)
      dataset.where(user_visibility_filter(user))
    end

    def self.user_visibility_filter(user)
      Sequel.or([
        [:space_guid, user.spaces_dataset.select(:guid)],
        [:space_guid, user.managed_spaces_dataset.select(:guid)],
        [:space_guid, user.audited_spaces_dataset.select(:guid)],
        [:space_guid, user.managed_organizations_dataset.join(
          :spaces, spaces__organization_id: :organizations__id
        ).select(:spaces__guid)],
      ])
    end

    def stage_with_diego?
      false
    end
  end
end
