require 'spec_helper'
require 'actions/user_delete'

module VCAP::CloudController
  RSpec.describe UserDeleteAction do
    subject(:user_delete) { UserDeleteAction.new }

    describe '#delete' do
      let!(:user) { User.make }

      it 'deletes the user record' do
        expect {
          user_delete.delete([user])
        }.to change { User.count }.by(-1)
        expect { user.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'recursive deletion' do
        let(:user) { User.make }
        let(:space) { Space.make }

        before do
          set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
          set_current_user_as_role(role: 'org_manager', org: space.organization, space: space, user: user)
        end

        it 'deletes the associated space roles' do
          expect {
            user_delete.delete([user])
          }.to change { user.spaces.count }.by(-1)
        end

        it 'deletes the associated org roles' do
          expect {
            user_delete.delete([user])
          }.to change { user.managed_organizations.count }.by(-1)
        end
      end
    end
  end
end
