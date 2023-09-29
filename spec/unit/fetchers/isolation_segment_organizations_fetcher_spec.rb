require 'spec_helper'
require 'fetchers/isolation_segment_organizations_fetcher'

module VCAP::CloudController
  RSpec.describe IsolationSegmentOrganizationsFetcher do
    subject(:fetcher) { IsolationSegmentOrganizationsFetcher.new(isolation_segment_model) }

    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }

    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }
    let(:org3) { VCAP::CloudController::Organization.make }
    let(:org4) { VCAP::CloudController::Organization.make }

    before do
      assigner.assign(isolation_segment_model, [org1, org2, org3])
    end

    describe '#fetch_all' do
      it 'returns all organizations in the allowed list' do
        organizations = fetcher.fetch_all

        expect(organizations).to contain_exactly(org1, org2, org3)
      end
    end

    describe '#fetch_for_organizations' do
      it 'fetches only organizations specified as readable' do
        organizations = fetcher.fetch_for_organizations(org_guids_query: Organization.where(id: [org1.id, org2.id, org4.id]).select(:guid))

        expect(organizations).to contain_exactly(org1, org2)
      end

      it 'returns no isolation segments when the list of org guids is empty' do
        organizations = fetcher.fetch_for_organizations(org_guids_query: Organization.where(id: -1).select(:guid))

        expect(organizations).to be_empty
      end
    end
  end
end
