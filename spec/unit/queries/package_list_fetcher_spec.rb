require 'spec_helper'
require 'queries/package_list_fetcher'

module VCAP::CloudController
  describe PackageListFetcher do
    describe '#fetch' do
      let(:app) { AppModel.make }
      let(:space) { app.space }
      let!(:package) { PackageModel.make(app_guid: app.guid) }
      let(:space_guids) { [space.guid] }
      let(:pagination_options) { PaginationOptions.new({}) }
      let(:fetcher) { described_class.new }

      describe '#fetch_all' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch_all(pagination_options)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns all of the packages' do
          PackageModel.make
          PackageModel.make
          PackageModel.make

          results = fetcher.fetch_all(pagination_options).records
          expect(results.length).to eq(PackageModel.count)
          expect(results).to include(package)
        end
      end

      describe '#fetch' do
        it 'returns a PaginatedResult' do
          results = fetcher.fetch(pagination_options, space_guids)
          expect(results).to be_a(PaginatedResult)
        end

        it 'returns only the packages in spaces requested' do
          package2 = PackageModel.make(app_guid: app.guid)
          PackageModel.make
          PackageModel.make

          results = fetcher.fetch(pagination_options, space_guids).records

          expect(results.length).to eq(PackageModel.where(space: Space.where(guid: space_guids)).count)
          expect(results.length).to be < (PackageModel.count)
          expect(results).to include(package)
          expect(results).to include(package2)
        end
      end
    end
  end
end
