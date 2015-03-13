require 'spec_helper'
require 'queries/app_fetcher'

module VCAP::CloudController
  describe AppFetcher do
    describe '#fetch' do
      let(:space) { Space.make }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:user) { User.make(admin: admin) }
      let(:admin) { false }

      context 'as an admin' do
        let(:admin) { true }

        it 'should return the desired app' do
          expect(AppFetcher.new(user).fetch(app_model.guid)).to eq(app_model)
        end
      end

      context 'as a user with correct permissions' do
        it 'should return the desired app' do
          space.organization.add_user(user)
          space.add_developer(user)

          expect(AppFetcher.new(user).fetch(app_model.guid)).to eq(app_model)
        end
      end

      context 'as a user without correct permission' do
        it 'should return nil' do
          expect(AppFetcher.new(user).fetch(app_model.guid)).to eq(nil)
        end
      end
    end
  end
end
