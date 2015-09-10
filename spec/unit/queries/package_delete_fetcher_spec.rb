require 'spec_helper'
require 'queries/package_delete_fetcher'

module VCAP::CloudController
  describe PackageDeleteFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }

      subject(:package_delete_fetcher) { PackageDeleteFetcher.new }

      it 'returns the package, space, and org' do
        expect(package_delete_fetcher.fetch(package.guid)).to include(package, space, org)
      end
    end
  end
end
