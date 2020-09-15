require 'spec_helper'
require 'fetchers/space_list_fetcher'

module VCAP::CloudController
  RSpec.describe SpaceListFetcher do
    let(:org1) { Organization.make(name: 'org1') }
    let(:org2) { Organization.make(name: 'org2') }

    let!(:space1) { Space.make(name: 'Lamb', organization: org1) }
    let!(:space2) { Space.make(name: 'Alpaca', organization: org2) }
    let!(:space3) { Space.make(name: 'Horse', organization: org1) }
    let!(:space4) { Space.make(name: 'Buffalo', organization: org2) }

    let(:message) { SpacesListMessage.from_params({}) }

    let(:fetcher) { SpaceListFetcher }

    describe '#fetch' do
      let(:permitted_space_guids) { [space1.guid, space3.guid, space4.guid] }

      it 'includes all the spaces with the provided guids' do
        results = fetcher.fetch(message: message, guids: permitted_space_guids).all
        expect(results).to match_array([space1, space3, space4])
      end

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all orgs' do
          results = fetcher.fetch(message: message, guids: permitted_space_guids, eager_loaded_associations: [:labels]).all

          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false

          expect(results.last.associations.key?(:labels)).to be true
          expect(results.last.associations.key?(:annotations)).to be false
        end
      end

      context 'when names filter is given' do
        let(:message) { SpacesListMessage.from_params({ names: ['Lamb', 'Buffalo'] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch(message: message, guids: permitted_space_guids).all
          expect(results).to match_array([space1, space4])
        end
      end

      context 'when organization_guids are provided' do
        let(:message) { SpacesListMessage.from_params({ organization_guids: [org2.guid] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch(message: message, guids: permitted_space_guids).all
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

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all orgs' do
          results = fetcher.fetch_all(message: message, eager_loaded_associations: [:labels]).all

          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false

          expect(results.last.associations.key?(:labels)).to be true
          expect(results.last.associations.key?(:annotations)).to be false
        end
      end

      context 'when names filter is given' do
        let(:message) { SpacesListMessage.from_params({ names: ['Lamb'] }) }

        it 'includes the spaces with the provided guids and matching the filter' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to match_array([space1])
        end
      end

      context 'when organization_guids are provided' do
        let(:message) { SpacesListMessage.from_params({ organization_guids: [org2.guid] }) }

        it 'includes the spaces belonging to the specified organizations' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to match_array([space2, space4])
        end
      end

      context 'when organization_guids  and a label_selector are provided' do
        let(:message) do SpacesListMessage.from_params(
          { organization_guids: [org2.guid], 'label_selector' => 'key2=value2' })
        end
        let!(:space1label) { SpaceLabelModel.make(key_name: 'key', value: 'value', space: space1) }
        let!(:space2label) { SpaceLabelModel.make(key_name: 'key2', value: 'value2', space: space2) }

        it 'returns the correct set of spaces' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to contain_exactly(space2)
        end
      end

      context 'when a label_selector is provided' do
        let(:message) do SpacesListMessage.from_params({ 'label_selector' => 'key=value' })
        end
        let!(:space1label) { SpaceLabelModel.make(key_name: 'key', value: 'value', space: space1) }
        let!(:space2label) { SpaceLabelModel.make(key_name: 'key2', value: 'value2', space: space2) }

        it 'returns the correct set of spaces' do
          results = fetcher.fetch_all(message: message).all
          expect(results).to contain_exactly(space1)
        end
      end
    end
  end
end
