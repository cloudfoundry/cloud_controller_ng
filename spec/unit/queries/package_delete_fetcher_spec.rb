require 'spec_helper'
require 'queries/package_delete_fetcher'

module VCAP::CloudController
  describe PackageDeleteFetcher do
    describe '#fetch' do
      let!(:package) { PackageModel.make }

      subject(:package_delete_fetcher) { PackageDeleteFetcher.new }

      it 'returns the package, nothing else' do
        expect(package_delete_fetcher.fetch(package.guid)).to include(package)
      end
    end
  end
end
