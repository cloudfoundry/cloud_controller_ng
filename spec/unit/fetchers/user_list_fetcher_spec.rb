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
    end
  end
end
