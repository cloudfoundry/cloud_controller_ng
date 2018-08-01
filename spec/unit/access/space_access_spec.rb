require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceAccess, type: :access do
    subject(:access) { SpaceAccess.new(Security::AccessContext.new) }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:user) { VCAP::CloudController::User.make }
    let(:scopes) { nil }

    let(:object) { VCAP::CloudController::Space.make(organization: org) }

    before { set_current_user(user, scopes: scopes) }

    it_behaves_like :admin_full_access
    it_behaves_like :admin_read_only_access

    context 'as an organization manager' do
      before { org.add_manager(user) }
      it_behaves_like :full_access

      context 'when the organization is suspended' do
        before { object.organization.status = 'suspended' }
        it_behaves_like :read_only_access
      end
    end

    context 'as a space manager' do
      before do
        org.add_user(user)
        object.add_manager(user)
      end

      it { is_expected.not_to allow_op_on_object :create, object }
      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.to allow_op_on_object :read_for_update, object }
      it { is_expected.to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :delete, object }

      context 'when the organization is suspended' do
        before { object.organization.status = 'suspended' }

        it_behaves_like :read_only_access
      end
    end

    context 'as a space developer' do
      before do
        org.add_user(user)
        object.add_developer(user)
      end

      it_behaves_like :read_only_access
    end

    context 'as a space auditor' do
      before do
        org.add_user(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only_access
    end

    context 'as an organization auditor (defensive)' do
      before { org.add_auditor(user) }
      it_behaves_like :no_access
    end

    context 'as an organization billing manager (defensive)' do
      before { org.add_billing_manager(user) }
      it_behaves_like :no_access
    end

    context 'as an organization user (defensive)' do
      before { org.add_user(user) }
      it_behaves_like :no_access
    end

    context 'as a user in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_user(user)
      end

      it_behaves_like :no_access
    end

    context 'as a manager in a different organization (defensive)' do
      before do
        different_organization = VCAP::CloudController::Organization.make
        different_organization.add_manager(user)
      end

      it_behaves_like :no_access
    end

    context 'a user that isnt logged in (defensive)' do
      let(:user) { nil }
      let(:roles) { double(:roles, admin?: false, none?: true, present?: false) }
      it_behaves_like :no_access
    end

    context 'any user using client without cloud_controller.write' do
      let(:scopes) { ['cloud_controller.read'] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        object.add_manager(user)
        object.add_developer(user)
        object.add_auditor(user)
      end

      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.read' do
      let(:scopes) { [] }

      before do
        org.add_user(user)
        org.add_manager(user)
        org.add_billing_manager(user)
        org.add_auditor(user)
        object.add_manager(user)
        object.add_developer(user)
        object.add_auditor(user)
      end

      it_behaves_like :no_access
    end

    describe '#can_remove_related_object?' do
      let(:params) { { relation: relation, related_guid: related_guid } }
      let(:space) { object }

      context 'with auditors' do
        let(:relation) { :auditors }

        context 'when acting against themselves' do
          let(:related_guid) { user.guid }

          it 'is true' do
            expect(access.can_remove_related_object?(space, params)).to be true
          end
        end

        context 'when acting against another' do
          let(:related_guid) { 123456 }

          it 'is false' do
            expect(access.can_remove_related_object?(space, params)).to be false
          end
        end
      end

      context 'with developers' do
        context 'when acting against themselves'
        let(:relation) { :developers }

        context 'when acting against themselves' do
          let(:related_guid) { user.guid }

          it 'is true' do
            expect(access.can_remove_related_object?(space, params)).to be true
          end
        end

        context 'when acting against another' do
          let(:related_guid) { 123456 }

          it 'is false' do
            expect(access.can_remove_related_object?(space, params)).to be false
          end
        end
      end

      context 'with managers' do
        let(:relation) { :managers }

        before do
          org.add_user(user)
          org.add_manager(user)
          space.add_manager(user)
        end

        context 'when acting against themselves' do
          let(:related_guid) { user.guid }

          it 'is true' do
            expect(access.can_remove_related_object?(space, params)).to be true
          end
        end

        context 'when acting against another' do
          let(:related_guid) { 123456 }

          it 'is true' do
            expect(access.can_remove_related_object?(space, params)).to be true
          end
        end
      end

      context 'with apps' do
        let(:relation) { :apps }
        let(:related_guid) { user.guid }

        it 'is false even when the guid matches the current user' do
          expect(access.can_remove_related_object?(space, params)).to be false
        end
      end
    end
  end
end
