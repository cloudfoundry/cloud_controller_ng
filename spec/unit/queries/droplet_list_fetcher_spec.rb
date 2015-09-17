require 'spec_helper'
require 'queries/droplet_list_fetcher'
require 'messages/droplets_list_message'

module VCAP::CloudController
  describe DropletListFetcher do
    let(:app_in_space) { AppModel.make }
    let(:desired_space) { app_in_space.space }
    let(:sad_app_in_space) { AppModel.make(space_guid: desired_space.guid) }
    let(:sad_app) { AppModel.make }
    let!(:desired_droplet) { DropletModel.make(app_guid: app_in_space.guid, state: 'STAGING') }
    let!(:desired_droplet2) { DropletModel.make(app_guid: app_in_space.guid, state: 'STAGING') }
    let!(:sad_droplet_in_space) { DropletModel.make(app_guid: sad_app_in_space.guid, state: 'STAGING') }
    let!(:undesirable_droplet) { DropletModel.make(state: 'STAGING') }
    let(:space_guids) { [desired_space.guid] }
    let(:app_guids) { [] }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:fetcher) { described_class.new }
    let(:message) { DropletsListMessage.new(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_all(pagination_options, message)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns all of the droplets' do
        results = fetcher.fetch_all(pagination_options, message).records

        expect(results.length).to eq(4)
        expect(results).to match_array([desired_droplet, desired_droplet2, sad_droplet_in_space, undesirable_droplet])
      end

      context 'when the app guids are provided' do
        let(:filters) { { app_guids: [app_in_space.guid, undesirable_droplet.app_guid] } }

        it 'returns all of the droplets for the requested app guids' do
          results = fetcher.fetch_all(pagination_options, message).records

          expect(results.length).to eq 3
          expect(results).to match_array([desired_droplet, desired_droplet2, undesirable_droplet])
        end
      end
    end

    describe '#fetch' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch(pagination_options, space_guids, message)
        expect(results).to be_a(PaginatedResult)
      end

      context 'when no filters are specified' do
        it 'returns all of the desired droplets in the requested spaces' do
          results = fetcher.fetch(pagination_options, space_guids, message).records

          expect(results.length).to eq 3
          expect(results).to match_array([desired_droplet, desired_droplet2, sad_droplet_in_space])
        end
      end

      context 'when the app guids are provided' do
        let(:filters) { { app_guids: [app_in_space.guid] } }
        let!(:sad_droplet) { DropletModel.make(state: 'STAGING') }

        it 'returns all of the desired droplets for the requested app guids' do
          results = fetcher.fetch(pagination_options, space_guids, message).records

          expect(results.length).to eq 2
          expect(results).not_to include(sad_droplet)
          expect(results).not_to include(sad_droplet_in_space)
          expect(results).to match_array([desired_droplet, desired_droplet2])
        end
      end

      context 'when the droplet states are provided' do
        let(:filters) { { states: ['PENDING', 'FAILED'] } }
        let!(:failed_droplet) { DropletModel.make(state: 'FAILED', app_guid: app_in_space.guid) }
        let!(:pending_droplet) { DropletModel.make(state: 'PENDING', app_guid: app_in_space.guid)  }
        let!(:undesirable_pending_droplet) { DropletModel.make(state: 'PENDING')  }

        it 'returns all of the desired droplets with the requested droplet states' do
          results = fetcher.fetch(pagination_options, space_guids, message).records

          expect(results.length).to eq 2
          expect(results).not_to include(undesirable_pending_droplet)
          expect(results).to match_array([failed_droplet, pending_droplet])
        end
      end
    end
  end
end
