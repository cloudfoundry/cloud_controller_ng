require 'spec_helper'
require 'fetchers/package_fetcher'

module VCAP::CloudController
  RSpec.describe PackageFetcher do
    describe '#fetch' do
      let(:package) { PackageModel.make }
      let(:space) { package.space }
      let(:org) { space.organization }

      it 'returns the desired package, space, org' do
        returned_package, returned_space, returned_org = PackageFetcher.new.fetch(package.guid)
        expect(returned_package).to eq(package)
        expect(returned_space).to eq(space)
        expect(returned_org).to eq(org)
      end

      context 'when the package is not found' do
        it 'returns nil' do
          returned_package, returned_space, returned_org = PackageFetcher.new.fetch('bogus-guid')
          expect(returned_package).to be_nil
          expect(returned_space).to be_nil
          expect(returned_org).to be_nil
        end
      end
    end
  end
end
