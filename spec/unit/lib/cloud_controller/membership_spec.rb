require 'spec_helper'

module VCAP::CloudController
  describe Membership do
    let(:user) { User.make }
    let!(:space) { Space.make(organization: organization) }
    let(:organization) { Organization.make }

    let(:membership) { Membership.new(user) }

    describe '#has_any_roles?' do
      it 'returns true for admins' do
        user.update(admin: true)
        result = membership.has_any_roles?('anything')
        expect(result).to be_truthy
      end

      context 'when space roles are provided' do
        before do
          organization.add_user(user)
        end

        describe 'SPACE_DEVELOPER' do
          context 'when the user has the role' do
            before do
              space.add_developer(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::SPACE_DEVELOPER, space.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              space.remove_developer(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::SPACE_DEVELOPER, space.guid)
              expect(result).to be_falsey
            end
          end
        end

        describe 'SPACE_MANAGER' do
          context 'when the user has the role' do
            before do
              space.add_manager(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::SPACE_MANAGER, space.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              space.remove_manager(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::SPACE_MANAGER, space.guid)
              expect(result).to be_falsey
            end
          end
        end

        describe 'SPACE_AUDITOR' do
          context 'when the user has the role' do
            before do
              space.add_auditor(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::SPACE_AUDITOR, space.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              space.remove_auditor(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::SPACE_AUDITOR, space.guid)
              expect(result).to be_falsey
            end
          end
        end

        context 'when the user has any one of multiple requested roles' do
          before do
            space.add_manager(user)
            space.remove_developer(user)
            space.remove_auditor(user)
          end

          it 'returns true' do
            result = membership.has_any_roles?([
              Membership::SPACE_MANAGER,
              Membership::SPACE_DEVELOPER,
              Membership::SPACE_AUDITOR], space.guid)

            expect(result).to be_truthy
          end
        end

        context 'when the user has none of multiple requested roles' do
          before do
            space.remove_manager(user)
            space.remove_developer(user)
            space.remove_auditor(user)
          end

          it 'returns false' do
            result = membership.has_any_roles?([
              Membership::SPACE_MANAGER,
              Membership::SPACE_DEVELOPER,
              Membership::SPACE_AUDITOR], space.guid)

            expect(result).to be_falsey
          end
        end

        context 'when the space_guid is nil' do
          it 'returns false' do
            result = membership.has_any_roles?(Membership::SPACE_DEVELOPER)
            expect(result).to be_falsey
          end
        end

        context 'when the space is in a suspended org and the user has the required role' do
          before do
            space.add_developer(user)
            space.add_manager(user)
            space.add_auditor(user)
            organization.status = 'suspended'
            organization.save
            space.save
          end

          it 'returns false' do
            result = membership.has_any_roles?([
              Membership::SPACE_DEVELOPER,
              Membership::SPACE_MANAGER,
              Membership::SPACE_AUDITOR],
              space.guid)
            expect(result).to be_falsey
          end
        end
      end

      context 'when org roles are provided' do
        before do
          organization.add_user(user)
        end

        describe 'ORG_MEMBER' do
          before do
            organization.add_user(user)
          end

          context 'when the user has the role' do
            before do
              organization.add_user(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::ORG_MEMBER, nil, organization.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              organization.remove_user(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::ORG_MEMBER, nil, organization.guid)
              expect(result).to be_falsey
            end
          end
        end

        describe 'ORG_MANAGER' do
          context 'when the user has the role' do
            before do
              organization.add_manager(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::ORG_MANAGER, nil, organization.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              organization.remove_manager(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::ORG_MANAGER, nil, organization.guid)
              expect(result).to be_falsey
            end
          end
        end

        describe 'ORG_AUDITOR' do
          context 'when the user has the role' do
            before do
              organization.add_auditor(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::ORG_AUDITOR, nil, organization.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              organization.remove_auditor(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::ORG_AUDITOR, nil, organization.guid)
              expect(result).to be_falsey
            end
          end
        end

        describe 'ORG_BILLING_MANAGER' do
          context 'when the user has the role' do
            before do
              organization.add_billing_manager(user)
            end

            it 'returns true' do
              result = membership.has_any_roles?(Membership::ORG_BILLING_MANAGER, nil, organization.guid)
              expect(result).to be_truthy
            end
          end

          context 'when the user does not have the role' do
            before do
              organization.remove_billing_manager(user)
            end

            it 'returns false' do
              result = membership.has_any_roles?(Membership::ORG_BILLING_MANAGER, nil, organization.guid)
              expect(result).to be_falsey
            end
          end
        end

        context 'when the user has any one of multiple requested roles' do
          before do
            organization.add_manager(user)
            organization.remove_billing_manager(user)
            organization.remove_auditor(user)
          end

          it 'returns true' do
            result = membership.has_any_roles?([
              Membership::ORG_MANAGER,
              Membership::ORG_BILLING_MANAGER,
              Membership::ORG_AUDITOR], nil, organization.guid)

            expect(result).to be_truthy
          end
        end

        context 'when the user has none of multiple requested roles' do
          before do
            organization.remove_manager(user)
            organization.remove_billing_manager(user)
            organization.remove_auditor(user)
          end

          it 'returns false' do
            result = membership.has_any_roles?([
              Membership::ORG_MANAGER,
              Membership::ORG_BILLING_MANAGER,
              Membership::ORG_AUDITOR], nil, organization.guid)

            expect(result).to be_falsey
          end
        end

        context 'when the org_guid is nil' do
          before do
            space.add_developer(user)
          end

          it 'returns false' do
            result = membership.has_any_roles?(Membership::ORG_MEMBER, space.guid, nil)
            expect(result).to be_falsey
          end
        end

        context 'when the org is suspended and the user has the required role' do
          before do
            organization.add_user(user)
            organization.add_manager(user)
            organization.add_billing_manager(user)
            organization.add_auditor(user)
            organization.status = 'suspended'
            organization.save
            space.save
          end

          it 'returns false' do
            result = membership.has_any_roles?([
              Membership::ORG_MEMBER,
              Membership::ORG_MANAGER,
              Membership::ORG_AUDITOR,
              Membership::ORG_BILLING_MANAGER],
              nil, organization.guid)
            expect(result).to be_falsey
          end
        end
      end

      context 'when space and org roles are provided' do
        before do
          organization.add_user(user)
        end

        context 'when the user has any one of multiple requested roles' do
          before do
            space.add_manager(user)
            space.remove_developer(user)
            space.remove_auditor(user)
            organization.add_manager(user)
          end

          it 'returns true' do
            result = membership.has_any_roles?([
              Membership::ORG_MANAGER,
              Membership::SPACE_MANAGER,
              Membership::SPACE_DEVELOPER,
              Membership::SPACE_AUDITOR
            ],
            space.guid, organization.guid)

            expect(result).to be_truthy
          end
        end

        context 'when the user has none of multiple requested roles' do
          before do
            space.remove_manager(user)
            space.remove_developer(user)
            space.remove_auditor(user)
            organization.remove_manager(user)
          end

          it 'returns false' do
            result = membership.has_any_roles?([
              Membership::ORG_MANAGER,
              Membership::SPACE_MANAGER,
              Membership::SPACE_DEVELOPER,
              Membership::SPACE_AUDITOR
            ],
            space.guid, organization.guid)

            expect(result).to be_falsey
          end
        end
      end
    end

    describe '#space_guids_for_roles' do
      let(:user) { User.make }

      before do
        organization.add_user(user)
      end

      context 'space developers' do
        before do
          space.add_developer(user)
        end

        it 'returns all spaces in which the user develops' do
          guids = membership.space_guids_for_roles(Membership::SPACE_DEVELOPER)

          expect(guids).to eq([space.guid])
        end
      end

      context 'space managers' do
        before do
          space.add_manager(user)
        end

        it 'returns all spaces that the user managers' do
          guids = membership.space_guids_for_roles(Membership::SPACE_MANAGER)

          expect(guids).to eq([space.guid])
        end
      end

      context 'space auditors' do
        before do
          space.add_auditor(user)
        end

        it 'returns all spaces that the user audits' do
          guids = membership.space_guids_for_roles(Membership::SPACE_AUDITOR)

          expect(guids).to eq([space.guid])
        end
      end

      context 'org member' do
        it 'returns all spaces that the user is in the org' do
          guids = membership.space_guids_for_roles(Membership::ORG_MEMBER)

          expect(guids).to eq([space.guid])
        end
      end

      context 'org manager' do
        before do
          organization.add_manager(user)
        end

        it 'returns all spaces that the user org manages' do
          guids = membership.space_guids_for_roles(Membership::ORG_MANAGER)

          expect(guids).to eq([space.guid])
        end
      end

      context 'org billing manager' do
        before do
          organization.add_billing_manager(user)
        end

        it 'returns all spaces that the user org billing manages' do
          guids = membership.space_guids_for_roles(Membership::ORG_BILLING_MANAGER)

          expect(guids).to eq([space.guid])
        end
      end

      context 'org auditor' do
        before do
          organization.add_auditor(user)
        end

        it 'returns all spaces that the user org audits' do
          guids = membership.space_guids_for_roles(Membership::ORG_AUDITOR)

          expect(guids).to eq([space.guid])
        end
      end

      context 'mix of org and space roles' do
        let(:org_managed) { Organization.make }
        let(:org_audited) { Organization.make }
        let!(:space1_in_managed_org) { Space.make(organization: org_managed) }
        let!(:space2_in_managed_org) { Space.make(organization: org_managed) }
        let!(:space_in_audited_org) { Space.make(organization: org_audited) }
        let!(:some_other_space) { Space.make }

        before do
          org_managed.add_manager(user)
          org_audited.add_auditor(user)
          space.add_developer(user)
        end

        it 'returns the correct spaces' do
          guids = membership.space_guids_for_roles([Membership::ORG_MANAGER, Membership::SPACE_DEVELOPER])

          expect(guids).to include(space1_in_managed_org.guid, space2_in_managed_org.guid, space.guid)
          expect(guids).not_to include(space_in_audited_org.guid, some_other_space.guid)
        end
      end
    end
  end
end
