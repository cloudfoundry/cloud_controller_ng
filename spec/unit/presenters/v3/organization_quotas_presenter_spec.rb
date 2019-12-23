require 'spec_helper'
require 'presenters/v3/organization_quotas_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OrganizationQuotasPresenter do
    let(:organization_quota) do
      VCAP::CloudController::QuotaDefinition.make(guid: 'quota-guid')
    end
    describe '#to_hash' do
      let(:result) { OrganizationQuotasPresenter.new(organization_quota).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(organization_quota.guid)
        expect(result[:created_at]).to eq(organization_quota.created_at)
        expect(result[:updated_at]).to eq(organization_quota.updated_at)
        expect(result[:name]).to eq(organization_quota.name)
        expect(result[:apps][:total_memory_in_mb]).to eq(20480)
        expect(result[:apps][:per_process_memory_in_mb]).to eq(nil)
        expect(result[:apps][:total_instances]).to eq(nil)
        expect(result[:apps][:per_app_tasks]).to eq(nil)

        expect(result[:links][:self][:href]).to match(%r{/v3/organization_quotas/#{organization_quota.guid}$})
        expect(result[:relationships][:organizations][:data]).to eq([])
      end

      context 'when there are associated orgs' do
        let(:org) { VCAP::CloudController::Organization.make }

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
