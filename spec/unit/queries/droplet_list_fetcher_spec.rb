require 'spec_helper'
require 'queries/droplet_list_fetcher'

module VCAP::CloudController
  describe DropletListFetcher do
    describe '#fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let!(:droplet) { DropletModel.make(app_guid: app.guid) }
      let(:space_guids) { [space.guid] }
      let(:pagination_options) { PaginationOptions.new({}) }
      let(:fetcher) { described_class.new }

      describe '#fetch_all' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch_all(pagination_options)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns all of the droplets' do
          DropletModel.make
          DropletModel.make
          DropletModel.make

          results = fetcher.fetch_all(pagination_options).records
          expect(results.length).to eq(DropletModel.count)
          expect(results).to include(droplet)
        end
      end

      describe '#fetch' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch(pagination_options, space_guids)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns only the droplets in spaces requested' do
          droplet2 = DropletModel.make(app_guid: app.guid)
          DropletModel.make
          DropletModel.make

          results = fetcher.fetch(pagination_options, space_guids).records

          expect(results.length).to eq(DropletModel.where(space: Space.where(guid: space_guids)).count)
          expect(results.length).to be < (DropletModel.count)
          expect(results).to include(droplet)
          expect(results).to include(droplet2)
        end
      end
    end
  end
end
