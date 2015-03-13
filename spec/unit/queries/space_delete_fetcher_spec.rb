require 'spec_helper'
require 'queries/space_delete_fetcher'

module VCAP::CloudController
  describe SpaceDeleteFetcher do
    describe '#fetch' do
      let(:space) { Space.make }

      subject(:space_delete_fetcher) { SpaceDeleteFetcher.new(space.guid) }

      it 'returns the space' do
        expect(space_delete_fetcher.fetch).to include(space)
      end
    end
  end
end
