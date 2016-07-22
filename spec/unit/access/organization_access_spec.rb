require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationAccess, type: :access do
    subject(:access) { OrganizationAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }
    let(:user) { VCAP::CloudController::User.make }
    let(:object) { VCAP::CloudController::Organization.make }

    before { set_current_user(user, scopes: scopes) }

    shared_examples :read_and_create_only do
      it { is_expected.to allow_op_on_object :create, object }
      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      # update only runs if read_for_update succeeds
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.not_to allow_op_on_object :delete, object }
      it { is_expected.to allow_op_on_object :index, object.class }
    end

    it_behaves_like :admin_read_only_access

    context 'admin' do
      include_context :admin_setup
      it_behaves_like :full_access

      it 'can set billing_enabled' do
        object.billing_enabled = !object.billing_enabled
        expect(subject.update?(object)).to be true
      end

      it 'can set quota_definition' do
        object.quota_definition = QuotaDefinition.make
        expect(subject.update?(object)).to be true
      end

      it 'can read related objects' do
        expect(subject.read_related_object_for_update?(object)).to be true
      end
    end

    context 'a manager for the organization' do
      before do
        object.add_manager(user)
        object.add_manager(User.make)
      end

      context 'with an active organization' do
        it { is_expected.not_to allow_op_on_object :create, object }
        it { is_expected.not_to allow_op_on_object :delete, object }
        it { is_expected.to allow_op_on_object :read, object }
        it { is_expected.to allow_op_on_object :read_for_update, object }
        it { is_expected.to allow_op_on_object :update, object }
        it { is_expected.to allow_op_on_object :index, object.class }
      end

      context 'with a suspended organization' do
        before { object.status = 'suspended' }

        it_behaves_like :read_only_access
      end

      it 'cannot set billing_enabled' do
        object.billing_enabled = !object.billing_enabled
        expect(subject.read_for_update?(object, { 'billing_enabled' => 1 })).to be false
      end

      it 'cannot set quota_definition' do
        object.quota_definition = QuotaDefinition.make
        expect(subject.read_for_update?(object, { 'quota_definition_guid' => 1 })).to be false
      end

      it 'can read related objects' do
        expect(subject.read_related_object_for_update?(object)).to be true
      end
    end

    context 'a user in the organization' do
      before { object.add_user(user) }

      it_behaves_like :read_only_access

      context 'a user' do
        let(:relation) { :users }

        context 'who is the user' do
          let(:related) { user }

          it 'can read_related_object_for_update? for themself' do
            params = { relation: relation, related_guid: related.guid }
            expect(subject.can_remove_related_object?(object, params)).to be true
          end
        end

        context 'who is not the user' do
          let(:related) { User.make }

          it 'can not can_remove_related_object? for that user' do
            params = { relation: relation, related_guid: related.guid }
            expect(subject.can_remove_related_object?(object, params)).to be false
          end
        end
      end
    end

    context 'a user not in the organization' do
      context 'when the user_org_creation feature flag is disabled' do
        it_behaves_like :no_access
      end

      context 'when the user_org_creation feature flag is enabled' do
        before do
          FeatureFlag.make(name: 'user_org_creation', enabled: true, error_message: nil)
        end

        it { is_expected.to allow_op_on_object :create, object }
      end
    end

    context 'a billing manager for the organization' do
      before { object.add_billing_manager(user) }

      it_behaves_like :read_only_access
    end

    context 'an auditor for the organization' do
      before { object.add_auditor(user) }

      it_behaves_like :read_only_access
    end

    context 'any user using client without cloud_controller.write' do
      let(:scopes) { ['cloud_controller.read'] }

      before do
        object.add_user(user)
        object.add_manager(user)
        object.add_billing_manager(user)
        object.add_auditor(user)
      end

      it { is_expected.not_to allow_op_on_object :create, object }
      it { is_expected.not_to allow_op_on_object :delete, object }
      it { is_expected.to allow_op_on_object :read, object }
      it { is_expected.not_to allow_op_on_object :read_for_update, object }
      it { is_expected.not_to allow_op_on_object :update, object }
      it { is_expected.to allow_op_on_object :index, object.class }
    end

    context 'any user using client without cloud_controller.read' do
      let(:scopes) { [] }

      before do
        object.add_user(user)
        object.add_manager(user)
        object.add_billing_manager(user)
        object.add_auditor(user)
      end

      it_behaves_like :no_access
    end
  end
end
