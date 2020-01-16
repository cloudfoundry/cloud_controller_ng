require 'spec_helper'
require 'presenters/v3/space_quota_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpaceQuotaPresenter do
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:space_2) { VCAP::CloudController::Space.make(organization: org) }

    let(:space_quota) do
      VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'quota-guid', organization: org)
    end

    before do
      space_quota.add_space(space_1)
      space_quota.add_space(space_2)
    end

    describe '#to_hash' do
      let(:result) { SpaceQuotaPresenter.new(space_quota).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(space_quota.guid)
        expect(result[:created_at]).to eq(space_quota.created_at)
        expect(result[:updated_at]).to eq(space_quota.updated_at)
        expect(result[:name]).to eq(space_quota.name)

        expect(result[:relationships][:organization][:data][:guid]).to eq(org.guid)
        expect(result[:relationships][:spaces][:data]).to eq([
          { guid: space_1.guid },
          { guid: space_2.guid }
        ])

        expect(result[:links][:self][:href]).to match(%r{/v3/space_quotas/#{space_quota.guid}$})
        expect(result[:links][:organization][:href]).to match(%r{/v3/organizations/#{org.guid}$})
      end
    end
  end
end
