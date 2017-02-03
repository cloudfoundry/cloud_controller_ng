require 'spec_helper'
require 'queries/space_list_fetcher'

module VCAP::CloudController
  RSpec.describe SpaceListFetcher do
    let!(:space1) { Space.make(name: 'Lamb') }
    let!(:space2) { Space.make(name: 'Alpaca') }
    let!(:space3) { Space.make(name: 'Horse') }
    let!(:space4) { Space.make(name: 'Buffalo') }

    let(:fetcher) { described_class.new }

    describe '#fetch' do
      let(:space_guids) { [space1.guid, space3.guid, space4.guid] }

      it 'includes all the spaces with the provided guids' do
        results = fetcher.fetch(guids: space_guids).all
        expect(results).to match_array([space1, space3, space4])
      end
    end

    describe '#fetch_all' do
      it 'fetches all the spaces' do
        all_spaces = fetcher.fetch_all
        expect(all_spaces.count).to eq(4)

        expect(all_spaces).to match_array([
          space1, space2, space3, space4
        ])
      end
    end
  end
end
