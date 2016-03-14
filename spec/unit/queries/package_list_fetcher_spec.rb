require 'spec_helper'
require 'queries/package_list_fetcher'

module VCAP::CloudController
  describe PackageListFetcher do
    subject(:fetcher) { described_class.new }
    let(:pagination_options) { PaginationOptions.new({}) }

    describe '#fetch_all' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_all(pagination_options: pagination_options)
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns all of the packages' do
        package1 = PackageModel.make
        package2 = PackageModel.make
        package3 = PackageModel.make

        results = fetcher.fetch_all(pagination_options: pagination_options).records
        expect(results).to match_array([package1, package2, package3])
      end
    end

    describe '#fetch_for_spaces' do
      it 'returns a PaginatedResult' do
        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [])
        expect(results).to be_a(PaginatedResult)
      end

      it 'returns only the packages in spaces requested' do
        space1        = Space.make
        app_in_space1 = AppModel.make(space: space1)
        package1_in_space1 = PackageModel.make(app_guid: app_in_space1.guid)
        package2_in_space1 = PackageModel.make(app_guid: app_in_space1.guid)

        space2        = Space.make
        app_in_space2 = AppModel.make(space: space2)
        package1_in_space2 = PackageModel.make(app_guid: app_in_space2.guid)

        PackageModel.make

        results = fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: [space1.guid, space2.guid]).records

        expect(results).to match_array([package1_in_space1, package2_in_space1, package1_in_space2])
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }

      it 'returns a PaginatedResult and the app' do
        returned_app, results = fetcher.fetch_for_app(pagination_options: pagination_options, app_guid: app.guid)
        expect(results).to be_a(PaginatedResult)
        expect(returned_app.guid).to eq(app.guid)
      end

      it 'returns only the packages for the app requested' do
        package1 = PackageModel.make(app_guid: app.guid)
        package2 = PackageModel.make(app_guid: app.guid)
        PackageModel.make
        PackageModel.make

        _app, results = fetcher.fetch_for_app(pagination_options: pagination_options, app_guid: app.guid)

        expect(results.records).to match_array([package1, package2])
      end

      context 'when the app does not exist' do
        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app(pagination_options: pagination_options, app_guid: 'made-up')
          expect(results).to be_nil
          expect(returned_app).to be_nil
        end
      end
    end
  end
end
