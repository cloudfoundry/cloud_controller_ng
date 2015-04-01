require 'spec_helper'
require 'queries/package_stage_fetcher'

module VCAP::CloudController
  describe PackageStageFetcher do
    describe '#fetch' do
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:package) { PackageModel.make(app_guid: app_model.guid) }
      let(:user) { User.make(admin: admin) }
      let(:buildpack) { Buildpack.make }
      let(:admin) { false }

      subject(:package_stage_fetcher) { PackageStageFetcher.new(user) }

      context 'when the user is an admin' do
        let(:admin) { true }

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

      context 'when the organization is not active' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
          space.organization.status = 'suspended'
          space.organization.save
        end

        it 'returns package, app, space, org, and buildpack to be nil' do
          actual_package, actual_app, actual_space, actual_org, actual_buildpack = package_stage_fetcher.fetch(package.guid, buildpack.guid)
          expect(actual_package).to be_nil
          expect(actual_app).to be_nil
          expect(actual_space).to be_nil
          expect(actual_org).to be_nil
          expect(actual_buildpack).to be_nil
        end
      end

      context 'when the user is a space developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'returns the process, app, space, org, and buildpack' do
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

      context 'when the user does not have access to deleting processes' do
        it 'returns nothing' do
          actual_package, actual_app, actual_space, actual_org, actual_buildpack = package_stage_fetcher.fetch(package.guid, buildpack.guid)
          expect(actual_package).to be_nil
          expect(actual_app).to be_nil
          expect(actual_space).to be_nil
          expect(actual_org).to be_nil
          expect(actual_buildpack).to be_nil
        end
      end
    end
  end
end
