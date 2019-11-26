require 'spec_helper'
require 'fetchers/user_list_fetcher'

module VCAP::CloudController
  RSpec.describe UserListFetcher do
    describe '#fetch_all' do
      subject { UserListFetcher.fetch_all(message, User.dataset) }

      let!(:user1) { User.make }
      let!(:user2) { User.make }
      let(:message) { UsersListMessage.from_params(filters) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the users' do
          expect(subject).to match_array([user1, user2])
        end
      end

      context 'when the users are filtered by guid' do
        let(:filters) { { guids: [user2.guid] } }

        it 'returns all of the desired users' do
          expect(subject).to match_array([user2])
        end
      end

      context 'when the users are filtered by username' do
        let(:filters) { { 'usernames' => 'user2-username' } }
        let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }

        before do
          allow(VCAP::CloudController::UaaClient).to receive(:new).and_return(uaa_client)
          allow(uaa_client).to receive(:ids_for_usernames_and_origins).with(['user2-username'], nil).and_return([user2.guid])
        end

        it 'returns all of the desired users' do
          expect(subject).to match_array([user2])
        end
      end

      context 'when the users are filtered by username and origin' do
        let(:filters) { { 'usernames' => 'user2-username', 'origins' => 'user2-origin' } }
        let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }

        before do
          allow(VCAP::CloudController::UaaClient).to receive(:new).and_return(uaa_client)
          allow(uaa_client).to receive(:ids_for_usernames_and_origins).with(['user2-username'], ['user2-origin']).and_return([user2.guid])
        end

        it 'returns all of the desired users' do
          expect(subject).to match_array([user2])
        end
      end

      context 'when fetching users by label selector' do
        let!(:org1) { Organization.make(guid: 'org1') }
        let!(:user_label) do
          VCAP::CloudController::UserLabelModel.make(resource_guid: user1.guid, key_name: 'dog', value: 'scooby-doo')
        end

        let!(:sad_user_label) do
          VCAP::CloudController::UserLabelModel.make(resource_guid: user2.guid, key_name: 'dog', value: 'poodle')
        end

        let(:results) { UserListFetcher.fetch_all(message, User.dataset).all }

        context 'only the label_selector is present' do
          let(:message) {
            UsersListMessage.from_params({ 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }
          it 'returns only the user whose label matches' do
            expect(results.length).to eq(1)
            expect(results[0]).to eq(user1)
          end
        end

        context 'and other filters are present' do
          let!(:happiest_user) { User.make }
          let(:message) {
            UsersListMessage.from_params({ 'guids' => happiest_user.guid, 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }

          let!(:happiest_user_label) do
            VCAP::CloudController::UserLabelModel.make(resource_guid: happiest_user.guid, key_name: 'dog', value: 'scooby-doo')
          end

          it 'returns the desired app' do
            expect(results).to contain_exactly(happiest_user)
          end
        end
      end
    end
  end
end
