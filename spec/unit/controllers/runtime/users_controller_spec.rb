require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UsersController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:managed_organization_guid) }
      it { expect(described_class).to be_queryable_by(:billing_managed_organization_guid) }
      it { expect(described_class).to be_queryable_by(:audited_organization_guid) }
      it { expect(described_class).to be_queryable_by(:managed_space_guid) }
      it { expect(described_class).to be_queryable_by(:audited_space_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          guid: { type: 'string', required: true },
          admin: { type: 'bool', default: false },
          space_guids: { type: '[string]' },
          organization_guids: { type: '[string]' },
          managed_organization_guids: { type: '[string]' },
          billing_managed_organization_guids: { type: '[string]' },
          audited_organization_guids: { type: '[string]' },
          managed_space_guids: { type: '[string]' },
          audited_space_guids: { type: '[string]' },
          default_space_guid: { type: 'string' },
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          admin: { type: 'bool' },
          space_guids: { type: '[string]' },
          organization_guids: { type: '[string]' },
          managed_organization_guids: { type: '[string]' },
          billing_managed_organization_guids: { type: '[string]' },
          audited_organization_guids: { type: '[string]' },
          managed_space_guids: { type: '[string]' },
          audited_space_guids: { type: '[string]' },
          default_space_guid: { type: 'string' },
        })
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes(
          {
            spaces:                        [:get, :put, :delete],
            organizations:                 [:get, :put, :delete],
            managed_organizations:         [:get, :put, :delete],
            billing_managed_organizations: [:get, :put, :delete],
            audited_organizations:         [:get, :put, :delete],
            managed_spaces:                [:get, :put, :delete],
            audited_spaces:                [:get, :put, :delete],
          }
        )
      end
    end

    describe 'permissions' do
      include_context 'permissions'
      before do
        @obj_a = member_a
        allow_any_instance_of(UaaClient).to receive(:usernames_for_ids).and_return({})
      end

      context 'normal user' do
        before { @obj_b = member_b }
        let(:member_a) { @org_a_manager }
        let(:member_b) { @space_a_manager }
        include_examples 'permission enumeration', 'User',
                         name: 'user',
                         path: '/v2/users',
                         enumerate: :not_allowed
      end

      context 'admin user' do
        let(:member_a) { User.make }
        let(:enumeration_expectation_a) { User.order(:id).limit(50) }

        include_examples 'permission enumeration', 'Admin',
                         name: 'user',
                         path: '/v2/users',
                         enumerate: proc { User.count },
                         permissions_overlap: true,
                         user_opts: { admin: true }
      end
    end

    describe 'GET /v2/users/:guid/organizations' do
      let(:mgr) { User.make }
      let(:user) { User.make }
      let(:org) { Organization.make(manager_guids: [mgr.guid], user_guids: [user.guid]) }

      before { set_current_user(user) }

      it 'allows the user' do
        get "/v2/users/#{user.guid}/organizations"
        expect(last_response.status).to eq(200)
      end

      it 'disallows a different user' do
        get "/v2/users/#{mgr.guid}/organizations"
        expect(last_response.status).to eq(403)
      end
    end

    describe 'DELETE /v2/users/:guid/audited_organizations/:org_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:user) { User.make }

      before do
        set_current_user(user)
        org.add_auditor(user)
      end

      context 'when acting on behalf of the current user' do
        it 'succeeds' do
          delete "/v2/users/#{user.guid}/audited_organizations/#{org.guid}"
          expect(last_response.status).to eq(204)
        end
      end

      context 'when acting on another user' do
        let(:other_user) { User.make }

        before do
          org.add_auditor(other_user)
        end

        it 'fails with 403' do
          delete "/v2/users/#{other_user.guid}/audited_organizations/#{org.guid}"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end

      context 'as a manager' do
        context 'when acting on another user' do
          let(:other_user) { User.make }

          before do
            org.add_manager(user)
            org.add_auditor(other_user)
          end

          it 'succeeds' do
            delete "/v2/users/#{other_user.guid}/audited_organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/audited_spaces/:space_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:user) { User.make }

      before do
        set_current_user(user)
        org.add_user(user)
        org.add_auditor(user)
        space.add_auditor(user)
      end

      context 'when acting on behalf of the current user' do
        it 'succeeds' do
          delete "/v2/users/#{user.guid}/audited_spaces/#{space.guid}"
          expect(last_response.status).to eq(204)
        end
      end

      context 'when acting on another user' do
        let(:other_user) { User.make }

        before do
          org.add_user(other_user)
          org.add_auditor(other_user)
          space.add_auditor(other_user)
        end

        it 'fails with 403' do
          delete "/v2/users/#{other_user.guid}/audited_spaces/#{space.guid}"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end

      context 'as a manager' do
        context 'when acting on another user' do
          let(:other_user) { User.make }

          before do
            org.add_manager(user)
            space.add_manager(user)
            org.add_user(other_user)
            org.add_auditor(other_user)
            space.add_auditor(other_user)
          end

          it 'succeeds' do
            delete "/v2/users/#{other_user.guid}/audited_spaces/#{space.guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/billing_managed_organizations/:org_guid' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:billing_manager) { User.make }
      let(:org) { space.organization }

      before do
        org.add_user user
        org.add_billing_manager billing_manager
        org.save
      end

      describe 'removing the last billing manager' do
        context 'as an admin' do
          before do
            set_current_user(user)
            set_current_user_as_admin
          end

          it 'is allowed' do
            delete "/v2/users/#{billing_manager.guid}/billing_managed_organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end

        context 'as the billing manager' do
          before { set_current_user(billing_manager) }

          it 'removing yourself is not allowed' do
            delete "/v2/users/#{billing_manager.guid}/billing_managed_organizations/#{org.guid}"
            expect(last_response.status).to eql(403)
            expect(decoded_response['code']).to eq(30005)
          end
        end
      end

      describe 'when there are other billing managers' do
        let(:other_billing_manager) { User.make }

        before do
          org.add_billing_manager other_billing_manager
          set_current_user billing_manager
        end

        describe 'removing oneself' do
          it 'is allowed' do
            set_current_user(billing_manager)
            delete "/v2/users/#{billing_manager.guid}/billing_managed_organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end

        describe 'removing other billing manager' do
          it 'is not allowed' do
            set_current_user(billing_manager)
            delete "/v2/users/#{other_billing_manager.guid}/billing_managed_organizations/#{org.guid}"
            expect(last_response.status).to eql(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/managed_organizations/:org_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:org_manager) { User.make }

      before do
        org.add_user org_manager
        org.add_manager org_manager
      end

      describe 'removing the last org manager' do
        context 'as an admin' do
          let(:admin) { User.make }

          before do
            set_current_user admin
            set_current_user_as_admin
          end

          it 'is allowed' do
            delete "/v2/users/#{org_manager.guid}/managed_organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end

        context 'as the lone org manager' do
          it 'is not allowed' do
            set_current_user(org_manager)

            delete "/v2/users/#{org_manager.guid}/managed_organizations/#{org.guid}"
            expect(last_response.status).to eql(403)
            expect(decoded_response['code']).to eq(30004)
          end
        end
      end

      describe 'when there are other managers' do
        before { org.add_manager User.make }

        describe 'removing oneself' do
          before { set_current_user(org_manager) }

          it 'is allowed' do
            delete "/v2/users/#{org_manager.guid}/managed_organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end

        context 'as a non-admin non-manager' do
          let(:user) { User.make }
          before do
            org.add_user user
            set_current_user user
          end

          it 'is not allowed' do
            delete "/v2/users/#{org_manager.guid}/managed_organizations/#{org.guid}"
            expect(last_response.status).to eql(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/organizations/:org_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:user) { User.make }

      before do
        set_current_user(user)
        org.add_user(user)
      end

      context 'as an org user' do
        it 'successfully removes itself' do
          delete "/v2/users/#{user.guid}/organizations/#{org.guid}"
          expect(last_response.status).to eq(204)
        end

        context 'when acting on another org user' do
          let(:other_user) { User.make }

          before do
            org.add_user(other_user)
          end

          it 'fails with 403' do
            delete "/v2/users/#{other_user.guid}/organizations/#{org.guid}"
            expect(last_response.status).to eq(403)
            expect(decoded_response['code']).to eq(10003)
          end
        end
      end

      context 'as a manager' do
        before do
          org.add_manager(user)
        end

        it 'succeeds removing itself if it is not the only manager' do
          org.add_manager(User.make)
          delete "/v2/users/#{user.guid}/organizations/#{org.guid}"
          expect(last_response.status).to eq(204)
        end

        it 'cannot remove itself if it is the only manager' do
          delete "/v2/users/#{user.guid}/organizations/#{org.guid}"
          expect(last_response.status).to eq(403)
        end
      end

      context 'as a billing manager' do
        before do
          org.add_billing_manager(user)
        end

        it 'can remove itself if it is not the only billing manager' do
          org.add_billing_manager(User.make)
          delete "/v2/users/#{user.guid}/organizations/#{org.guid}"
          expect(last_response.status).to eq(204)
        end

        it 'cannot remove itself if it is the only billing manager' do
          delete "/v2/users/#{user.guid}/organizations/#{org.guid}"
          expect(last_response.status).to eq(403)
        end
      end

      context 'as an admin' do
        context 'when acting on another user' do
          let(:other_user) { User.make }

          before do
            org.add_user other_user
            set_current_user_as_admin
          end

          it 'succeeds' do
            delete "/v2/users/#{other_user.guid}/organizations/#{org.guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/managed_spaces/:space_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:user) { User.make }
      let(:other_user) { User.make }

      before do
        set_current_user(user)
      end

      context 'as a manager' do
        before do
          org.add_user(user)
          space.add_manager(user)
        end

        context 'when acting on another user' do
          before do
            org.add_user(other_user)
            space.add_manager(other_user)
          end

          it 'succeeds' do
            delete "/v2/users/#{other_user.guid}/managed_spaces/#{space.guid}"
            expect(last_response.status).to eq(204)
          end
        end

        context 'when acting on oneself' do
          it 'succeeds' do
            delete "/v2/users/#{user.guid}/managed_spaces/#{space.guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end

      context 'as a non-manager' do
        context 'when acting on another user' do
          it 'fails with a 403' do
            delete "/v2/users/#{other_user.guid}/managed_spaces/#{space.guid}"
            expect(last_response.status).to eq(403)
          end
        end
      end
    end

    describe 'DELETE /v2/users/:guid/spaces/:space_guid' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:user) { User.make }

      before do
        set_current_user(user)
        org.add_user(user)
        space.add_developer(user)
      end

      context 'when acting on behalf of the current user' do
        it 'succeeds' do
          delete "/v2/users/#{user.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(204)
          expect(Space.all).to include(space)
        end
      end

      context 'when acting on another user' do
        let(:other_user) { User.make }

        before do
          org.add_user(other_user)
          space.add_developer(other_user)
        end

        it 'fails with 403' do
          delete "/v2/users/#{other_user.guid}/spaces/#{space.guid}"
          expect(last_response.status).to eq(403)
          expect(decoded_response['code']).to eq(10003)
        end
      end

      context 'as a manager' do
        context 'when acting on another user' do
          let(:other_user) { User.make }

          before do
            org.add_manager(user)
            space.add_manager(user)
            org.add_user(other_user)
            space.add_developer(other_user)
          end

          it 'succeeds' do
            delete "/v2/users/#{other_user.guid}/spaces/#{space.guid}"
            expect(last_response.status).to eq(204)
          end
        end
      end
    end
  end
end
