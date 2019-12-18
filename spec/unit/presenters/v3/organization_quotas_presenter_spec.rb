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
        expect(result[:links][:self][:href]).to match(%r{/v3/organization_quotas/#{organization_quota.guid}$})
      end
    end
  end
end
