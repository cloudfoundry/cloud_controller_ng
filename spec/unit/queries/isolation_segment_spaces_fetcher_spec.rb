require 'spec_helper'
require 'fetchers/isolation_segment_spaces_fetcher'

module VCAP::CloudController
  RSpec.describe IsolationSegmentSpacesFetcher do
    subject(:fetcher) { described_class.new(isolation_segment_model) }

    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }

    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }

    let(:space1) { VCAP::CloudController::Space.make(organization: org1) }
    let(:space2) { VCAP::CloudController::Space.make(organization: org2) }
    let(:space3) { VCAP::CloudController::Space.make(organization: org2) }

    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    before do
      assigner.assign(isolation_segment_model, [org1, org2])
      isolation_segment_model.add_space(space1)
      isolation_segment_model.add_space(space2)
      isolation_segment_model.add_space(space3)
    end

    describe '#fetch_all' do
      it 'returns all associated spaces' do
        spaces = fetcher.fetch_all

        expect(spaces).to contain_exactly(space1, space2, space3)
      end
    end

    describe '#fetch_for_spaces' do
      it 'fetches only spaces specified as readable' do
        spaces = fetcher.fetch_for_spaces(space_guids: [space1.guid, space2.guid])

        expect(spaces).to contain_exactly(space1, space2)
      end

      it 'returns no spaces when the list of space guids is empty' do
        spaces = fetcher.fetch_for_spaces(space_guids: [])

        expect(spaces).to be_empty
      end
    end
  end
end
