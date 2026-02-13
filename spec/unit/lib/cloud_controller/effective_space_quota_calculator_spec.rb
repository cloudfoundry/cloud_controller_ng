require 'spec_helper'
require 'cloud_controller/effective_space_quota_calculator'

module VCAP::CloudController
  RSpec.describe EffectiveSpaceQuotaCalculator do
    let(:org_quota) { QuotaDefinition.make(memory_limit: 500, log_rate_limit: 1000, app_instance_limit: 50, app_task_limit: 10, total_service_keys: -1) }
    let(:org) { Organization.make(quota_definition: org_quota) }

    context 'when space has no space quota defined' do
      let(:space) { Space.make(organization: org) }

      it 'returns the organization quota as the effective space quota' do
        effective_quota = described_class.calculate(space)
        expect(effective_quota.as_json).to include(org_quota.as_json.except('name', 'trial_db_allowed'))
      end
    end

    context 'when space has a space quota defined' do
      let(:space_quota) do
        SpaceQuotaDefinition.make(organization: org, memory_limit: 200, log_rate_limit: 2000, app_instance_limit: 100, app_task_limit: -1, total_service_keys: 2)
      end
      let(:space) { Space.make(organization: org, space_quota_definition: space_quota) }

      it 'calculates the effective space quota based on space and organization quotas' do
        effective_quota = described_class.calculate(space)
        expect(effective_quota.memory_limit).to eq(200)
        expect(effective_quota.log_rate_limit).to eq(1000)
        expect(effective_quota.app_instance_limit).to eq(50)
        expect(effective_quota.app_task_limit).to eq(10)
        expect(effective_quota.total_service_keys).to eq(2)
      end
    end

    context 'when org has no organization quota defined' do
      let(:org) { Organization.make(quota_definition: nil) }
      let(:space_quota) do
        SpaceQuotaDefinition.make(organization: org, memory_limit: 200, log_rate_limit: 2000, app_instance_limit: 100, app_task_limit: -1, total_service_keys: 2,
                                  total_reserved_route_ports: 0)
      end
      let(:space) { Space.make(organization: org, space_quota_definition: space_quota) }

      it 'returns the space quota as the effective space quota' do
        effective_quota = described_class.calculate(space)
        # Ignore fields which are not part of space quota, not relevant or deprecated
        expect(effective_quota.as_json.except('total_private_domains')).to include(space_quota.as_json.except('name', 'trial_db_allowed', 'organization_guid'))
      end
    end
  end
end
