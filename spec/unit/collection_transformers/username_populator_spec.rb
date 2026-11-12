require 'spec_helper'

module VCAP::CloudController
  RSpec.describe UsernamePopulator do
    let(:uaa_client) { double(UaaClient) }
    let(:username_populator) { UsernamePopulator.new(uaa_client) }
    let(:user1) { User.new(guid: '1') }
    let(:user2) { User.new(guid: '2') }

    before do
      allow(uaa_client).to receive(:usernames_for_ids).with(%w[1 2]).and_return({
                                                                                  '1' => 'Username1',
                                                                                  '2' => 'Username2'
                                                                                })
      allow(uaa_client).to receive(:usernames_for_ids).with(['1']).and_return({
                                                                                '1' => 'Username1'
                                                                              })
    end

    describe 'transform' do
      it 'populates an array of users with usernames from UAA' do
        username_populator.transform([user1, user2])
        expect(user1.username).to eq('Username1')
        expect(user2.username).to eq('Username2')
      end

      it 'populates one user with its username from UAA' do
        username_populator.transform(user1)
        expect(user1.username).to eq('Username1')
      end

      it 'delegates qualified account lookup to the model while retaining UAA lookup for other users' do
        account = ServiceAccountModel.create(name: 'payments-worker', space: create(:space, :with_service_account_prefix))
        account_user = User.new(guid: account.client_id, is_oauth_client: true)
        other_client = User.new(guid: 'other-client', is_oauth_client: true)
        expect(ServiceAccountModel).to receive(:for_client_ids).with([account.client_id, other_client.guid]).and_call_original
        expect(uaa_client).to receive(:usernames_for_ids).with(%w[1 other-client]).and_return('1' => 'Username1')

        username_populator.transform([account_user, user1, other_client])

        expect(account_user.username).to eq(account.name)
        expect(user1.username).to eq('Username1')
        expect(other_client.username).to be_nil
      end
    end
  end
end
