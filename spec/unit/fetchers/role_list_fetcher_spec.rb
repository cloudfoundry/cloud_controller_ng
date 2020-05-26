require 'spec_helper'
require 'fetchers/role_list_fetcher'

module VCAP::CloudController
  RSpec.describe RoleListFetcher do
    describe '#fetch' do
      subject { RoleListFetcher.fetch(message, Role.dataset) }

      let!(:user1) { User.make }
      let!(:user2) { User.make }
      let!(:org_1) { Organization.make }
      let!(:org_2) { Organization.make }
      let!(:space_1) { Space.make(organization: org_1) }
      let!(:space_2) { Space.make(organization: org_2) }
      let!(:space_1_role_1) { SpaceAuditor.make(user: user1, space: space_1) }
      let!(:space_2_role_1) { SpaceAuditor.make(user: user1, space: space_2) }
      let!(:org_1_role_1) { OrganizationUser.make(user: user1, organization: org_1) }
      let!(:space_1_role_2) { SpaceManager.make(user: user2, space: space_1) }
      let!(:org_1_role_2) { OrganizationUser.make(user: user2, organization: org_1) }

      let(:message) { RolesListMessage.from_params(filters) }

      context 'eager loading associated resources' do
        let(:filters) { {} }

        it 'eager loads the specified resources for the routes' do
          results = RoleListFetcher.fetch(message, Role.dataset, eager_loaded_associations: [:user, :space]).all

          expect(results.first.associations.key?(:user)).to be true
          expect(results.first.associations.key?(:space)).to be true
          expect(results.first.associations.key?(:organization)).to be false
        end
      end

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the roles' do
          expect(subject.map(&:guid)).to match_array([space_1_role_1, space_2_role_1, org_1_role_1, space_1_role_2, org_1_role_2].map(&:guid))
        end
      end

      context 'when the roles are filtered by guid' do
        let(:filters) { { guids: [space_1_role_1.guid] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([space_1_role_1.guid])
        end
      end

      context 'when the roles are filtered by org_guid' do
        let(:filters) { { organization_guids: [org_1.guid] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([org_1_role_1, org_1_role_2].map(&:role_guid))
        end
      end

      context 'when the roles are filtered by types' do
        let(:filters) { { types: [RoleTypes::ORGANIZATION_USER] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([org_1_role_1, org_1_role_2].map(&:guid))
        end
      end

      context 'when the roles are filtered by user_guids' do
        let(:filters) { { user_guids: [user1.guid] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([org_1_role_1, space_1_role_1, space_2_role_1].map(&:guid))
        end
      end

      context 'when the roles are filtered by space_guid' do
        let(:filters) { { space_guids: [space_1.guid] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([space_1_role_2, space_1_role_1].map(&:guid))
        end
      end

      context 'when there are multiple filters' do
        let(:filters) { { space_guids: [space_1.guid], user_guids: [user1.guid], types: [RoleTypes::SPACE_MANAGER, RoleTypes::SPACE_AUDITOR] } }

        it 'returns all of the desired roles' do
          expect(subject.map(&:guid)).to match_array([space_1_role_1].map(&:guid))
        end
      end
    end
  end
end
