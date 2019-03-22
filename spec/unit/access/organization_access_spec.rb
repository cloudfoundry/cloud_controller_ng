require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationAccess, type: :access do
    let(:queryer) { instance_spy(Permissions::Queryer) }

    subject(:access) { OrganizationAccess.new(Security::AccessContext.new(queryer)) }
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:object) { org }
    let(:flag) { FeatureFlag.make(name: 'user_org_creation', enabled: false) }

    before do
      flag.save
    end

    index_table = {
      unauthenticated: true,
      reader_and_writer: true,
      reader: true,
      writer: true,

      admin: true,
      admin_read_only: true,
      global_auditor: true,

      org_user: true,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: true,
    }

    read_table = {
      unauthenticated: false,
      reader_and_writer: true,
      reader: true,
      writer: false,

      admin: true,
      admin_read_only: true,
      global_auditor: true,

      org_user: true,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: true,
    }

    write_table = {
      unauthenticated: false,
      reader_and_writer: false,
      reader: false,
      writer: false,

      admin: true,
      admin_read_only: false,
      global_auditor: false,

      org_user: false,
      org_manager: false,
      org_auditor: false,
      org_billing_manager: false,
    }

    update_table = write_table.clone.merge({
       org_manager: true,
    })

    remove_last_remaining_table = write_table.clone.merge({
      org_manager: false,
    })

    flag_enabled_create_table = {
      unauthenticated: false,
      reader_and_writer: true,
      reader: false,
      writer: true,

      admin: true,
      admin_read_only: false,
      global_auditor: false,

      org_user: true,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: true,
    }

    flag_disabled_create_table = write_table

    acting_on_self_table = {
      unauthenticated: false,
      reader_and_writer: true,
      reader: false,
      writer: true,

      admin: true,
      admin_read_only: false,
      global_auditor: false,

      org_user: true,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: true,
    }

    it_behaves_like('an access control', :index, index_table)

    describe 'user org creation feature flag' do
      context 'when the flag is enabled' do
        before do
          flag.enabled = true
          flag.save
        end

        it_behaves_like('an access control', :create, flag_enabled_create_table)
      end

      context 'when the flag is disabled' do
        it_behaves_like('an access control', :create, flag_disabled_create_table)
      end
    end

    describe 'in an unsuspended org' do
      it_behaves_like('an access control', :read, read_table)

      it_behaves_like('an access control', :delete, write_table)

      it_behaves_like('an access control', :read_for_update, update_table)
      it_behaves_like('an access control', :update, update_table)

      describe 'params' do
        context 'quota_definition_guid param is set' do
          let(:op_params) { { 'quota_definition_guid' => 'some-guid' } }

          it_behaves_like('an access control', :read_for_update, write_table)
        end

        context 'billing_enabled param is set' do
          let(:op_params) { { 'billing_enabled' => 'sure' } }

          it_behaves_like('an access control', :read_for_update, write_table)
        end
      end
    end

    describe 'in a suspended org' do
      let(:org) { VCAP::CloudController::Organization.make(status: VCAP::CloudController::Organization::SUSPENDED) }

      it_behaves_like('an access control', :read, read_table)
      it_behaves_like('an access control', :delete, write_table)
      it_behaves_like('an access control', :read_for_update, write_table)
      it_behaves_like('an access control', :update, write_table)
    end

    describe 'related objects' do
      context 'removing managers' do
        context 'when there is a manager other than the current user' do
          let(:manager) { VCAP::CloudController::User.make }
          let(:op_params) { { relation: :managers, related_guid: manager.guid } }

          before do
            org.add_manager(manager)
          end

          it_behaves_like('an access control', :can_remove_related_object, update_table, CloudController::Errors::ApiError)
        end

        context 'when there are no managers other than the current user' do
          let(:op_params) { { relation: :managers } }

          it_behaves_like('an access control', :can_remove_related_object, remove_last_remaining_table, CloudController::Errors::ApiError)
        end
      end

      context 'removing billing_managers' do
        context 'when there is only one remaining billing manager' do
          let(:op_params) { { relation: :managers } }

          before do
            org.add_billing_manager(user)
          end

          it_behaves_like('an access control', :can_remove_related_object, remove_last_remaining_table, CloudController::Errors::ApiError)
        end
      end

      context 'removing org users' do
        context 'when there is a manager other than the current user' do
          let(:org_user) { VCAP::CloudController::User.make }
          let(:op_params) { { related_guid: org_user.guid, relation: :users } }

          before do
            org.add_user(org_user)
          end

          it_behaves_like('an access control', :can_remove_related_object, update_table, CloudController::Errors::ApiError)
        end

        context 'when there are no users other than the current user' do
          let(:op_params) { { related_guid: user.guid, relation: :users } }

          it_behaves_like('an access control', :can_remove_related_object, remove_last_remaining_table, CloudController::Errors::ApiError)
        end
      end

      context 'acting on themselves' do
        let(:op_params) { { related_guid: user&.guid, relation: :auditors } }

        it_behaves_like('an access control', :can_remove_related_object, acting_on_self_table)
      end
    end
  end
end
