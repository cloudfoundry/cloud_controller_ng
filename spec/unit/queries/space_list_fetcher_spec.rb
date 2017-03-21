require 'spec_helper'
require 'fetchers/space_list_fetcher'

module VCAP::CloudController
  RSpec.describe SpaceListFetcher do
    let!(:space1) { Space.make(name: 'Lamb') }
    let!(:space2) { Space.make(name: 'Alpaca') }
    let!(:space3) { Space.make(name: 'Horse') }
    let!(:space4) { Space.make(name: 'Buffalo') }

    let(:message) { SpacesListMessage.new }

    let(:fetcher) { described_class.new }

    describe '#fetch' do
      let(:space_guids) { [space1.guid, space3.guid, space4.guid] }

      it 'includes all the spaces with the provided guids' do
        results = fetcher.fetch(message: message, guids: space_guids).all
        expect(results).to match_array([space1, space3, space4])
      end

      context 'when names filter is given' do
        let(:message) { SpacesListMessage.new({ names: ['Lamb', 'Buffalo'] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch(message: message, guids: space_guids).all
          expect(results).to match_array([space1, space4])
        end
      end

      context 'when organization_guids are provided' do
        let(:org1) { Organization.make }
        let(:org2) { Organization.make }

        let!(:space1) { Space.make(name: 'Lamb', organization: org1) }
        let!(:space2) { Space.make(name: 'Alpaca', organization: org2) }
        let!(:space3) { Space.make(name: 'Horse', organization: org1) }
        let!(:space4) { Space.make(name: 'Buffalo', organization: org2) }

        let(:message) { SpacesListMessage.new({ organization_guids: [org2.guid] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch(message: message, guids: space_guids).all
          expect(results).to match_array([space4])
        end
      end
    end

    describe '#fetch_all' do
      it 'fetches all the spaces' do
        all_spaces = fetcher.fetch_all(message: message)
        expect(all_spaces.count).to eq(4)

        expect(all_spaces).to match_array([
          space1, space2, space3, space4
        ])
      end

      context 'when names filter is given' do
        let(:message) { SpacesListMessage.new({ names: ['Lamb'] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to match_array([space1])
        end
      end

      context 'when organization_guids are provided' do
        let(:org1) { Organization.make }
        let(:org2) { Organization.make }

        let!(:space1) { Space.make(name: 'Lamb', organization: org1) }
        let!(:space2) { Space.make(name: 'Alpaca', organization: org2) }
        let!(:space3) { Space.make(name: 'Horse', organization: org1) }
        let!(:space4) { Space.make(name: 'Buffalo', organization: org2) }

        let(:message) { SpacesListMessage.new({ organization_guids: [org2.guid] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to match_array([space2, space4])
        end
      end
    end
  end
end
