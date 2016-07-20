require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Permissions do
    let(:user) { User.make }
    let(:space) { Space.make(organization: org) }
    let(:org) { Organization.make }
    let(:space_guid) { space.guid }
    let(:org_guid)   { org.guid }
    let(:permissions) { Permissions.new(user) }

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

        context 'and user is not an admin' do
          it 'return false' do
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

    describe '#can_see_secrets_in_space?' do
      context 'user has no membership' do
        context 'and user is an admin' do
          it 'returns true' do
            set_current_user(user, { admin: true })
            expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be true
          end
        end

        context 'and user is not an admin' do
          it 'return false' do
            set_current_user(user)
            expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be false
          end
        end
      end

      context 'user has valid membership' do
        it 'returns true for space developer' do
          org.add_user(user)
          space.add_developer(user)
          expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be true
        end

        it 'returns true for space manager' do
          org.add_user(user)
          space.add_manager(user)
          expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be true
        end

        it 'returns false for space auditor' do
          org.add_user(user)
          space.add_auditor(user)
          expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be false
        end

        it 'returns true for org manager' do
          org.add_manager(user)
          expect(permissions.can_see_secrets_in_space?(space_guid, org_guid)).to be true
        end
      end
    end

    describe '#readable_space_guids' do
      it 'returns space guids from membership' do
        space_guids = double
        membership = instance_double(Membership, space_guids_for_roles: space_guids)
        expect(Membership).to receive(:new).with(user).and_return(membership)
        expect(permissions.readable_space_guids).to eq(space_guids)
        expect(membership).to have_received(:space_guids_for_roles).with(VCAP::CloudController::Permissions::ROLES_FOR_READING)
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
  end
end
