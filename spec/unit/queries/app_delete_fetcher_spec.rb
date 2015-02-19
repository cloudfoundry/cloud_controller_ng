require 'spec_helper'
require 'queries/app_delete_fetcher'

module VCAP::CloudController
  describe AppDeleteFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:user) { User.make(admin: admin) }
      let(:admin) { false }

      subject(:app_delete_fetcher) { AppDeleteFetcher.new(user) }

      context 'when the user is an admin' do
        let(:admin) { true }

        it 'returns the app, nothing else' do
          expect(app_delete_fetcher.fetch(app_model.guid)).to include(app_model)
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
          expect(app_delete_fetcher.fetch(app_model.guid)).to be_empty
        end
      end

      context 'when the user is a space developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'returns the app, nothing else' do
          expect(app_delete_fetcher.fetch(app_model.guid)).to include(app_model)
        end
      end

      context 'when the user does not have access to deleting apps' do
        it 'returns nothing' do
          expect(app_delete_fetcher.fetch(app_model.guid)).to be_empty
        end
      end
    end
  end
end
