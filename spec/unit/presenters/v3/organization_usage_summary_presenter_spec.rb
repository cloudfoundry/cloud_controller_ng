require 'spec_helper'
require 'presenters/v3/organization_usage_summary_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OrganizationUsageSummaryPresenter do
    let(:org) { VCAP::CloudController::Organization.make }

    describe '#to_hash' do
      let(:result) { OrganizationUsageSummaryPresenter.new(org).to_hash }

      it 'presents the org as json' do
        expect(result[:usage_summary][:started_instances]).to eq(0)
        expect(result[:usage_summary][:memory_in_mb]).to eq(0)
        expect(result[:links][:self][:href]).to match(%r{/v3/organizations/#{org.guid}/usage_summary$})
        expect(result[:links][:organization][:href]).to match(%r{/v3/organizations/#{org.guid}$})
      end
    end
  end
end
