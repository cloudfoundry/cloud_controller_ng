module VCAP::CloudController
  module Jobs
    module V3
      class OrganizationQuotaDeleteJob < VCAP::CloudController::Jobs::DeleteActionJob
        def initialize(quota_guid)
          super(
            VCAP::CloudController::QuotaDefinition,
            quota_guid,
            VCAP::CloudController::OrganizationQuotaDeleteAction.new
          )
        end

        def resource_type
          'organization_quota'
        end
      end
    end
  end
end
