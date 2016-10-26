require 'spec_helper'
require 'queries/isolation_segment_organizations_fetcher'

module VCAP::CloudController
  RSpec.describe IsolationSegmentOrganizationsFetcher do
    subject(:fetcher) { described_class.new(isolation_segment_model) }

    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }

    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }
    let(:org3) { VCAP::CloudController::Organization.make }
    let(:org4) { VCAP::CloudController::Organization.make }

    before do
      isolation_segment_model.add_organization(org1)
      isolation_segment_model.add_organization(org2)
      isolation_segment_model.add_organization(org3)
    end

    describe '#fetch_all' do
      it 'returns all organizations in the allowed list' do
        organizations = fetcher.fetch_all

        expect(organizations).to match_array([org1, org2, org3])
      end
    end

    describe '#fetch_for_organizations' do
      it 'fetches only organizations specified as readable' do
        organizations = fetcher.fetch_for_organizations(org_guids: [org1.guid, org2.guid, org4.guid])

        expect(organizations).to contain_exactly(org1, org2)
      end

      it 'returns no isolation segments when the list of org guids is empty' do
        organizations = fetcher.fetch_for_organizations(org_guids: [])

        expect(organizations).to be_empty
      end
    end
  end
end
