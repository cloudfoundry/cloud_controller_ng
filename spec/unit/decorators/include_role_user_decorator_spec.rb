require 'spec_helper'
require 'decorators/include_role_user_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoleUserDecorator do
    subject(:decorator) { IncludeRoleUserDecorator }
    let(:user1) { User.make(guid: 'user-1-guid') }
    let(:user2) { User.make(guid: 'user-2-guid') }
    let(:roles) do
      [
        SpaceDeveloper.make(user: user1),
        OrganizationManager.make(user: user2)
      ]
    end

    describe '#decorate' do
      let(:uaa_client) { double(:uaa_client) }
      let(:user_uaa_info) do
        {
          user1.guid => { 'username' => 'user-1-name', 'origin' => 'uaa' },
          user2.guid => { 'username' => 'user-2-name', 'origin' => 'uaa' }
        }
      end

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
        allow(uaa_client).to receive(:users_for_ids).with([user1.guid, user2.guid]).and_return(user_uaa_info)
      end

      it 'decorates the given hash with associated users' do
        undecorated_hash = { foo: 'bar' }
        hash = subject.decorate(undecorated_hash, roles)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:users]).to contain_exactly(Presenters::V3::UserPresenter.new(user1, uaa_users: user_uaa_info).to_hash,
                                                           Presenters::V3::UserPresenter.new(user2, uaa_users: user_uaa_info).to_hash)
      end

      it 'does not overwrite other included fields' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
        hash = subject.decorate(undecorated_hash, roles)
        expect(hash[:foo]).to eq('bar')
        expect(hash[:included][:users]).to contain_exactly(Presenters::V3::UserPresenter.new(user1, uaa_users: user_uaa_info).to_hash,
                                                           Presenters::V3::UserPresenter.new(user2, uaa_users: user_uaa_info).to_hash)
        expect(hash[:included][:monkeys]).to match_array(%w[zach greg])
      end
    end

    describe '#match?' do
      it 'matches include arrays containing "user"' do
        expect(decorator).to be_match(%w[potato user turnip])
      end

      it 'does not match other include arrays' do
        expect(decorator).not_to be_match(%w[potato turnip])
      end
    end
  end
end
