require 'spec_helper'
require 'queries/droplet_list_fetcher'

module VCAP::CloudController
  describe AppDropletsListFetcher do
    let(:app) { AppModel.make }
    let(:sad_app) { AppModel.make }
    let!(:desired_droplet) { DropletModel.make(app_guid: app.guid, state: 'STAGING') }
    let!(:desired_droplet2) { DropletModel.make(app_guid: app.guid, state: 'STAGING') }
    let!(:sad_droplet) { DropletModel.make(app_guid: sad_app.guid, state: 'STAGING') }
    let(:app_guid) { app.guid }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:fetcher) { described_class.new }
    let(:message) { AppsDropletsListMessage.new(filters) }
    let(:filters) { {} }

    describe '#fetch' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch(app_guid, pagination_options, message)
        expect(results).to be_a(PaginatedResult)
      end

      context 'when no filters are specified' do
        it 'returns all of the desired droplets for the requested app' do
          results = fetcher.fetch(app_guid, pagination_options, message).records

          expect(results.length).to eq 2
          expect(results).to match_array([desired_droplet, desired_droplet2])
          expect(results).not_to include(sad_droplet)
        end
      end

      context 'when the droplet states are provided' do
        let(:filters) { { states: ['PENDING', 'FAILED'] } }
        let!(:failed_droplet) { DropletModel.make(state: 'FAILED', app_guid: app_guid) }
        let!(:pending_droplet) { DropletModel.make(state: 'PENDING', app_guid: app_guid)  }
        let!(:undesirable_pending_droplet) { DropletModel.make(state: 'PENDING')  }

        it 'returns all of the desired droplets with the requested droplet states' do
          results = fetcher.fetch(app_guid, pagination_options, message).records

          expect(results.length).to eq 2
          expect(results).not_to include(undesirable_pending_droplet)
          expect(results).to match_array([failed_droplet, pending_droplet])
        end
      end
    end
  end
end
