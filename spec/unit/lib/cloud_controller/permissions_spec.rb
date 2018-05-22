require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Permissions do
    let(:user) { User.make }
    let(:space) { Space.make(organization: org) }
    let(:org) { Organization.make }
    let(:space_guid) { space.guid }
    let(:org_guid)   { org.guid }
    let(:permissions) { Permissions.new(user) }

    describe '#can_read_globally?' do
      context 'and user is an admin' do
        it 'returns true' do
          set_current_user(user, { admin: true })
          expect(permissions.can_read_globally?).to be true
        end
      end

      context 'and the user is a read only admin' do
        it 'returns true' do
          set_current_user(user, { admin_read_only: true })
          expect(permissions.can_read_globally?).to be true
        end
      end

      context 'and user is a global auditor' do
        it 'returns true' do
          set_current_user_as_global_auditor
          expect(permissions.can_read_globally?).to be true
        end
      end

      context 'and user is none of the above' do
        it 'returns false' do
          set_current_user(user)
          expect(permissions.can_read_globally?).to be false
        end
      end
    end

    describe '#can_write_globally?' do
      context 'and user is an admin' do
        it 'returns true' do
          set_current_user(user, { admin: true })
          expect(permissions.can_write_globally?).to be true
        end
      end

      context 'and the user is a read only admin' do
        it 'returns false' do
          set_current_user(user, { admin_read_only: true })
          expect(permissions.can_write_globally?).to be false
        end
      end

      context 'and user is a global auditor' do
        it 'returns false' do
          set_current_user_as_global_auditor
          expect(permissions.can_write_globally?).to be false
        end
      end

      context 'and user is none of the above' do
        it 'returns false' do
          set_current_user(user)
          expect(permissions.can_write_globally?).to be false
        end
      end
    end

    describe '#readable_org_guids' do
      it 'returns all the org guids for admins' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1_guid = Organization.make.guid
        org2_guid = Organization.make.guid

        org_guids = subject.readable_org_guids

        expect(org_guids).to include(org1_guid)
        expect(org_guids).to include(org2_guid)
      end

      it 'returns all the org guids for read-only admins' do
        user = set_current_user_as_admin_read_only
        subject = Permissions.new(user)

        org1_guid = Organization.make.guid
        org2_guid = Organization.make.guid

        org_guids = subject.readable_org_guids

        expect(org_guids).to include(org1_guid)
        expect(org_guids).to include(org2_guid)
      end

      it 'returns all the org guids for global auditors' do
        user = set_current_user_as_global_auditor
        subject = Permissions.new(user)

        org1_guid = Organization.make.guid
        org2_guid = Organization.make.guid

        org_guids = subject.readable_org_guids

        expect(org_guids).to include(org1_guid)
        expect(org_guids).to include(org2_guid)
      end

      it 'returns org guids from membership' do
        org_guids = double
        membership = instance_double(Membership, org_guids_for_roles: org_guids)
        expect(Membership).to receive(:new).with(user).and_return(membership)
        expect(permissions.readable_org_guids).to eq(org_guids)
        expect(membership).to have_received(:org_guids_for_roles).with(VCAP::CloudController::Permissions::ROLES_FOR_ORG_READING)
      end
    end

    describe '#can_read_from_org?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user(user, { admin: true })
            expect(permissions.can_read_from_org?(org_guid)).to be true
          end
        end

        context 'and user is a read only admin' do
          it 'returns true' do
            set_current_user(user, { admin_read_only: true })
            expect(permissions.can_read_from_org?(org_guid)).to be true
          end
        end

        context 'and user is a global auditor' do
          it 'returns true' do
            set_current_user_as_global_auditor
            expect(permissions.can_read_from_org?(org_guid)).to be true
          end
        end

        context 'and user is not an admin' do
          it 'returns false' do
            set_current_user(user)
            expect(permissions.can_read_from_org?(org_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for org user' do
          org.add_user(user)
          expect(permissions.can_read_from_org?(org_guid)).to be true
        end

        it 'returns true for org auditor' do
          org.add_auditor(user)
          expect(permissions.can_read_from_org?(org_guid)).to be true
        end

        it 'returns true for org manager' do
          org.add_manager(user)
          expect(permissions.can_read_from_org?(org_guid)).to be true
        end

        it 'returns true for org billing manager' do
          org.add_billing_manager(user)
          expect(permissions.can_read_from_org?(org_guid)).to be true
        end
      end
    end

    describe '#can_write_to_org?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user(user, { admin: true })
            expect(permissions.can_read_from_org?(org_guid)).to be true
          end
        end

        context 'and user is a read only admin' do
          it 'returns false' do
            set_current_user(user, { admin_read_only: true })
            expect(permissions.can_write_to_org?(org_guid)).to be false
          end
        end

        context 'and user is a global auditor' do
          it 'returns false' do
            set_current_user_as_global_auditor
            expect(permissions.can_write_to_org?(org_guid)).to be false
          end
        end

        context 'and user is not an admin' do
          it 'returns false' do
            set_current_user(user)
            expect(permissions.can_write_to_org?(org_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns false for org user' do
          org.add_user(user)
          expect(permissions.can_write_to_org?(org_guid)).to be false
        end

        it 'returns false for org auditor' do
          org.add_auditor(user)
          expect(permissions.can_write_to_org?(org_guid)).to be false
        end

        it 'returns true for org manager' do
          org.add_manager(user)
          expect(permissions.can_write_to_org?(org_guid)).to be true
        end

        it 'returns false for org billing manager' do
          org.add_billing_manager(user)
          expect(permissions.can_write_to_org?(org_guid)).to be false
        end
      end
    end

    describe '#readable_space_guids' do
      it 'returns all the space guids for admins' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)

        space_guids = subject.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)
      end

      it 'returns all the space guids for read-only admins' do
        user = set_current_user_as_admin_read_only
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)

        space_guids = subject.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)
      end

      it 'returns all the space guids for global auditors' do
        user = set_current_user_as_global_auditor
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)

        space_guids = subject.readable_space_guids

        expect(space_guids).to include(space1.guid)
        expect(space_guids).to include(space2.guid)
      end

      it 'returns space guids from membership' do
        space_guids = double
        membership = instance_double(Membership, space_guids_for_roles: space_guids)
        expect(Membership).to receive(:new).with(user).and_return(membership)
        expect(permissions.readable_space_guids).to eq(space_guids)
        expect(membership).to have_received(:space_guids_for_roles).with(VCAP::CloudController::Permissions::ROLES_FOR_READING)
      end
    end

    describe '#can_read_from_space?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user(user, { admin: true })
            expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and the user is a read only admin' do
          it 'returns true' do
            set_current_user(user, { admin_read_only: true })
            expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and user is a global auditor' do
          it 'returns true' do
            set_current_user_as_global_auditor
            expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and user is not an admin' do
          it 'returns false' do
            set_current_user(user)
            expect(permissions.can_read_from_space?(space_guid, org_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for space developer' do
          org.add_user(user)
          space.add_developer(user)
          expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
        end

        it 'returns true for space manager' do
          org.add_user(user)
          space.add_manager(user)
          expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
        end

        it 'returns true for space auditor' do
          org.add_user(user)
          space.add_auditor(user)
          expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
        end

        it 'returns true for org manager' do
          org.add_manager(user)
          expect(permissions.can_read_from_space?(space_guid, org_guid)).to be true
        end
      end
    end

    describe '#can_read_secrets_in_space?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user_as_admin
            expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and user is admin_read_only' do
          it 'returns true' do
            set_current_user_as_admin_read_only
            expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and user is global auditor' do
          it 'return false' do
            set_current_user_as_global_auditor
            expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be false
          end
        end

        context 'and user is not an admin' do
          it 'return false' do
            set_current_user(user)
            expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for space developer' do
          org.add_user(user)
          space.add_developer(user)
          expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be true
        end

        it 'returns false for space manager' do
          org.add_user(user)
          space.add_manager(user)
          expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be false
        end

        it 'returns false for space auditor' do
          org.add_user(user)
          space.add_auditor(user)
          expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be false
        end

        it 'returns false for org manager' do
          org.add_manager(user)
          expect(permissions.can_read_secrets_in_space?(space_guid, org_guid)).to be false
        end
      end
    end

    describe '#can_write_to_space?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user(user, { admin: true })
            expect(permissions.can_write_to_space?(space_guid)).to be true
          end
        end

        context 'and user is admin_read_only' do
          it 'return false' do
            set_current_user_as_admin_read_only
            expect(permissions.can_write_to_space?(space_guid)).to be false
          end
        end

        context 'and user is global auditor' do
          it 'return false' do
            set_current_user_as_global_auditor
            expect(permissions.can_write_to_space?(space_guid)).to be false
          end
        end

        context 'and user is not an admin' do
          it 'return false' do
            set_current_user(user)
            expect(permissions.can_write_to_space?(space_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for space developer' do
          org.add_user(user)
          space.add_developer(user)
          expect(permissions.can_write_to_space?(space_guid)).to be true
        end

        it 'returns false for space manager' do
          org.add_user(user)
          space.add_manager(user)
          expect(permissions.can_write_to_space?(space_guid)).to be false
        end

        it 'returns false for space auditor' do
          org.add_user(user)
          space.add_auditor(user)
          expect(permissions.can_write_to_space?(space_guid)).to be false
        end

        it 'returns false for org manager' do
          org.add_manager(user)
          expect(permissions.can_write_to_space?(space_guid)).to be false
        end
      end
    end

    describe '#can_read_from_isolation_segment?' do
      let(:isolation_segment) { IsolationSegmentModel.make }
      let(:assigner) { IsolationSegmentAssign.new }

      before do
        assigner.assign(isolation_segment, [org])
      end

      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user_as_admin
            expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
          end
        end

        context 'and user is admin_read_only' do
          it 'returns true' do
            set_current_user_as_admin_read_only
            expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
          end
        end

        context 'and user is global auditor' do
          it 'return true' do
            set_current_user_as_global_auditor
            expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
          end
        end

        context 'and user is not an admin' do
          it 'return false' do
            set_current_user(user)
            expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for space developer' do
          org.add_user(user)
          space.add_developer(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for space manager' do
          org.add_user(user)
          space.add_manager(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for space auditor' do
          org.add_user(user)
          space.add_auditor(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for org manager' do
          org.add_manager(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for org auditor' do
          org.add_auditor(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for org member' do
          org.add_user(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end

        it 'returns true for org billing manager' do
          org.add_billing_manager(user)
          expect(permissions.can_read_from_isolation_segment?(isolation_segment)).to be true
        end
      end
    end

    describe '#readable_route_guids' do
      it 'returns all the route guids for admins' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        route1 = Route.make(space: space1)
        route2 = Route.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        route3 = Route.make(space: space2)

        route_guids = subject.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)
        expect(route_guids).to include(route3.guid)
      end

      it 'returns all the route guids for read-only admins' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        route1 = Route.make(space: space1)
        route2 = Route.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        route3 = Route.make(space: space2)

        route_guids = subject.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)
        expect(route_guids).to include(route3.guid)
      end

      it 'returns all the route guids for global auditors' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        route1 = Route.make(space: space1)
        route2 = Route.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        route3 = Route.make(space: space2)

        route_guids = subject.readable_route_guids

        expect(route_guids).to include(route1.guid)
        expect(route_guids).to include(route2.guid)
        expect(route_guids).to include(route3.guid)
      end

      it 'returns route guids where the user has an appropriate org membership' do
        manager_org = Organization.make
        manager_space = Space.make(organization: manager_org)
        manager_route = Route.make(space: manager_space)
        manager_org.add_manager(user)

        auditor_org = Organization.make
        auditor_space = Space.make(organization: auditor_org)
        auditor_route = Route.make(space: auditor_space)
        auditor_org.add_auditor(user)

        billing_manager_org = Organization.make
        billing_manager_space = Space.make(organization: billing_manager_org)
        billing_manager_route = Route.make(space: billing_manager_space)
        billing_manager_org.add_billing_manager(user)

        member_org = Organization.make
        member_space = Space.make(organization: member_org)
        member_route = Route.make(space: member_space)
        member_org.add_user(user)

        route_guids = permissions.readable_route_guids

        expect(route_guids).to contain_exactly(manager_route.guid, auditor_route.guid)
        expect(route_guids).not_to include(billing_manager_route.guid)
        expect(route_guids).not_to include(member_route.guid)
      end

      it 'returns route guids where the user has an appropriate space membership' do
        org = Organization.make
        org.add_user(user)

        developer_space = Space.make(organization: org)
        developer_route = Route.make(space: developer_space)
        developer_space.add_developer(user)

        manager_space = Space.make(organization: org)
        manager_route = Route.make(space: manager_space)
        manager_space.add_manager(user)

        auditor_space = Space.make(organization: org)
        auditor_route = Route.make(space: auditor_space)
        auditor_space.add_auditor(user)

        route_guids = permissions.readable_route_guids

        expect(route_guids).to contain_exactly(developer_route.guid, manager_route.guid, auditor_route.guid)
      end
    end

    describe '#can_read_route?' do
      it 'returns true if user is an admin' do
        set_current_user(user, { admin: true })
        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true if user is a read-only admin' do
        set_current_user(user, { admin_read_only: true })
        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true if user is a global auditor' do
        set_current_user_as_global_auditor
        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true for space developer' do
        org.add_user(user)
        space.add_developer(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true for space manager' do
        org.add_user(user)
        space.add_manager(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true for space auditor' do
        org.add_user(user)
        space.add_auditor(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true for org manager' do
        org.add_user(user)
        org.add_manager(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns true for org auditor' do
        org.add_user(user)
        org.add_auditor(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be true
      end

      it 'returns false for org billing manager' do
        org.add_user(user)
        org.add_billing_manager(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be false
      end

      it 'returns false for regular org member' do
        org.add_user(user)

        expect(permissions.can_read_route?(space_guid, org_guid)).to be false
      end

      it 'returns false for other user' do
        expect(permissions.can_read_route?(space_guid, org_guid)).to be false
      end
    end

    describe '#readable_app_guids' do
      it 'returns all the app guids for admins' do
        user = set_current_user_as_admin
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        app1 = AppModel.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        app2 = AppModel.make(space: space2)

        app_guids = subject.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)
      end

      it 'returns all the app guids for read-only admins' do
        user = set_current_user_as_admin_read_only
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        app1 = AppModel.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        app2 = AppModel.make(space: space2)

        app_guids = subject.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)
      end

      it 'returns all the app guids for global auditors' do
        user = set_current_user_as_global_auditor
        subject = Permissions.new(user)

        org1 = Organization.make
        space1 = Space.make(organization: org1)
        app1 = AppModel.make(space: space1)
        org2 = Organization.make
        space2 = Space.make(organization: org2)
        app2 = AppModel.make(space: space2)

        app_guids = subject.readable_app_guids

        expect(app_guids).to include(app1.guid)
        expect(app_guids).to include(app2.guid)
      end

      it 'returns app guids where the user has an appropriate org membership' do
        manager_org = Organization.make
        manager_space = Space.make(organization: manager_org)
        manager_app = AppModel.make(space: manager_space)
        manager_org.add_manager(user)

        auditor_org = Organization.make
        auditor_space = Space.make(organization: auditor_org)
        auditor_app = AppModel.make(space: auditor_space)
        auditor_org.add_auditor(user)

        billing_manager_org = Organization.make
        billing_manager_space = Space.make(organization: billing_manager_org)
        billing_manager_app = AppModel.make(space: billing_manager_space)
        billing_manager_org.add_billing_manager(user)

        member_org = Organization.make
        member_space = Space.make(organization: member_org)
        member_app = AppModel.make(space: member_space)
        member_org.add_user(user)

        app_guids = permissions.readable_app_guids

        expect(app_guids).to contain_exactly(manager_app.guid)
        expect(app_guids).not_to include(auditor_app.guid)
        expect(app_guids).not_to include(billing_manager_app.guid)
        expect(app_guids).not_to include(member_app.guid)
      end

      it 'returns app guids where the user has an appropriate space membership' do
        org = Organization.make
        org.add_user(user)

        developer_space = Space.make(organization: org)
        developer_app = AppModel.make(space: developer_space)
        developer_space.add_developer(user)

        manager_space = Space.make(organization: org)
        manager_app = AppModel.make(space: manager_space)
        manager_space.add_manager(user)

        auditor_space = Space.make(organization: org)
        auditor_app = AppModel.make(space: auditor_space)
        auditor_space.add_auditor(user)

        app_guids = permissions.readable_app_guids

        expect(app_guids).to contain_exactly(developer_app.guid, manager_app.guid, auditor_app.guid)
      end
    end
  end
end
