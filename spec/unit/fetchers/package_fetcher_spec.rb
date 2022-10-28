require 'spec_helper'
require 'fetchers/package_fetcher'

module VCAP::CloudController
  RSpec.describe PackageFetcher do
    describe '#fetch' do
      let(:package) { PackageModel.make }
      let(:space) { package.space }

      it 'returns the desired package and space' do
        returned_package, returned_space = PackageFetcher.new.fetch(package.guid)
        expect(returned_package).to eq(package)
        expect(returned_space).to eq(space)
      end

      context 'when the package is not found' do
        it 'returns nil' do
          returned_package, returned_space = PackageFetcher.new.fetch('bogus-guid')
          expect(returned_package).to be_nil
          expect(returned_space).to be_nil
        end
      end
    end
  end
end
