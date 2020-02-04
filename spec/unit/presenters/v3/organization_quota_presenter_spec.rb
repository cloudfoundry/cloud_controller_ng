require 'spec_helper'
require 'presenters/v3/organization_quota_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OrganizationQuotaPresenter do
    let(:organization_quota) { VCAP::CloudController::QuotaDefinition.make(guid: 'quota-guid') }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:visible_org_guids) { [org.guid] }

    describe '#to_hash' do
      let(:result) { OrganizationQuotaPresenter.new(organization_quota, visible_org_guids: visible_org_guids).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(organization_quota.guid)
        expect(result[:created_at]).to eq(organization_quota.created_at)
        expect(result[:updated_at]).to eq(organization_quota.updated_at)
        expect(result[:name]).to eq(organization_quota.name)

        expect(result[:apps][:total_memory_in_mb]).to eq(20480)
        expect(result[:apps][:per_process_memory_in_mb]).to eq(nil)
        expect(result[:apps][:total_instances]).to eq(nil)
        expect(result[:apps][:per_app_tasks]).to eq(nil)

        expect(result[:services][:paid_services_allowed]).to eq(true)
        expect(result[:services][:total_service_instances]).to eq(60)
        expect(result[:services][:total_service_keys]).to eq(nil)

        expect(result[:routes][:total_routes]).to eq(1000)
        expect(result[:routes][:total_reserved_ports]).to eq(5)

        expect(result[:domains][:total_domains]).to eq(nil)

        expect(result[:relationships][:organizations][:data]).to eq([])
        expect(result[:links][:self][:href]).to match(%r{/v3/organization_quotas/#{organization_quota.guid}$})
      end

      context 'when there are associated orgs' do
        before do
          organization_quota.add_organization(org)
        end

        it 'presents the org quota with the list of orgs' do
          expect(result[:relationships][:organizations][:data]).to eq([{ guid: org.guid }])
        end
      end
    end
  end
end
