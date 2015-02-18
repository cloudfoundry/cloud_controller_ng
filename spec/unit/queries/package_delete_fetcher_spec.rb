require 'spec_helper'
require 'queries/package_delete_fetcher'

module VCAP::CloudController
  describe PackageDeleteFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let!(:package) { PackageModel.make(app_guid: app_model.guid) }
      let!(:other_package) { PackageModel.make(app_guid: app_model.guid) }
      let(:user) { User.make(admin: admin) }
      let(:admin) { false }

      subject(:package_delete_fetcher) { PackageDeleteFetcher.new(user) }

      context 'when the user is an admin' do
        let(:admin) { true }

        it 'returns the package, nothing else' do
          expect(package_delete_fetcher.fetch(package.guid)).to eq(package)
        end
      end

      context 'when the organization is not active' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
          space.organization.status = 'suspended'
          space.organization.save
        end

        it 'returns nil' do
          expect(package_delete_fetcher.fetch(package.guid)).to be_nil
        end
      end

      context 'when the user is a space developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'returns the package, nothing else' do
          expect(package_delete_fetcher.fetch(package.guid)).to eq(package)
        end
      end

      context 'when the user does not have access to deleting packages' do
        it 'returns nothing' do
          expect(package_delete_fetcher.fetch(package.guid)).to be_nil
        end
      end
    end
  end
end
