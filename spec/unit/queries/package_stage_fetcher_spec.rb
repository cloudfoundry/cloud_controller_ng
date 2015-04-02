require 'spec_helper'
require 'queries/package_stage_fetcher'

module VCAP::CloudController
  describe PackageStageFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }
      let(:buildpack) { Buildpack.make }

      subject(:package_stage_fetcher) { PackageStageFetcher.new }

      it 'returns the package, app, space, org, and buildpack' do
        actual_package, actual_app, actual_space, actual_org, actual_buildpack = package_stage_fetcher.fetch(package.guid, buildpack.guid)
        expect(actual_package).to eq(package)
        expect(actual_app).to eq(app_model)
        expect(actual_space).to eq(space)
        expect(actual_org).to eq(org)
        expect(actual_buildpack).to eq(buildpack)
      end

      context 'when the buildpack does not exist' do
        it 'returns the package, app, space, org, and NIL buildpack' do
          actual_package, actual_app, actual_space, actual_org, actual_buildpack = package_stage_fetcher.fetch(package.guid, 'fake-guid')
          expect(actual_package).to eq(package)
          expect(actual_app).to eq(app_model)
          expect(actual_space).to eq(space)
          expect(actual_org).to eq(org)
          expect(actual_buildpack).to be_nil
        end
      end
    end
  end
end
