require 'spec_helper'
require 'fetchers/space_fetcher'

module VCAP::CloudController
  RSpec.describe SpaceFetcher do
    describe '#fetch' do
      let(:space) { Space.make }

      it 'returns the desired space' do
        returned_space = SpaceFetcher.new.fetch(space.guid)
        expect(returned_space).to eq(space)
      end

      context 'when the space is not found' do
        it 'returns nil' do
          returned_space = AppFetcher.new.fetch('bogus-guid')
          expect(returned_space).to be_nil
        end
      end
    end
  end
end
