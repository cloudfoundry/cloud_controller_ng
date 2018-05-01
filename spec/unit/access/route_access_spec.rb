require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteAccess, type: :access do
    subject(:access) { RouteAccess.new(Security::AccessContext.new) }
    let(:scopes) { ['cloud_controller.read', 'cloud_controller.write'] }

    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
    let(:flag) { FeatureFlag.make(name: 'route_creation', enabled: false) }
    let(:object) { VCAP::CloudController::Route.make(domain: domain, space: space) }

    before(:each) {
      set_current_user(user, scopes: scopes)
      flag.save
    }

    index_table = {
      unauthenticated: true,
      reader_and_writer: true,
      reader: true,
      writer: true,

      admin: true,
      admin_read_only: true,
      global_auditor: true,

      space_developer: true,
      space_manager: true,
      space_auditor: true,
      org_user: true,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: true,
    }

    read_table = {
      unauthenticated: false,
      reader_and_writer: false,
      reader: false,
      writer: false,

      admin: true,
      admin_read_only: true,
      global_auditor: true,

      space_developer: true,
      space_manager: true,
      space_auditor: true,
      org_user: false,
      org_manager: true,
      org_auditor: true,
      org_billing_manager: false,
    }

    reserved_table = {
      unauthenticated: false,
      reader_and_writer: true,
      reader: true,
      writer: false,

      admin: true,
      admin_read_only: false,
      global_auditor: false,
    }

    write_table = {
      unauthenticated: false,
      reader_and_writer: false,
      reader: false,
      writer: false,

      admin: true,
      admin_read_only: false,
      global_auditor: false,

      space_developer: true,
      space_manager: false,
      space_auditor: false,
      org_user: false,
      org_manager: false,
      org_auditor: false,
      org_billing_manager: false,
    }

    restricted_write_table = write_table.clone.merge({
      space_developer: false,
    })

    describe 'in a suspended org' do
      before(:each) do
        org.status = VCAP::CloudController::Organization::SUSPENDED
        org.save
      end

      it_behaves_like('an access control', :create, restricted_write_table)
      it_behaves_like('an access control', :delete, restricted_write_table)
      it_behaves_like('an access control', :index, index_table)
      it_behaves_like('an access control', :read, read_table)
      it_behaves_like('an access control', :read_for_update, restricted_write_table)
      it_behaves_like('an access control', :reserved, reserved_table)
      it_behaves_like('an access control', :update, restricted_write_table)
    end

    describe 'in an unsuspended org' do
      describe 'when route creation is enabled' do
        before(:each) do
          flag.enabled = true
          flag.save
        end

        describe 'in a shared domain' do
          before(:each) { object.domain = SharedDomain.make }

          describe 'when the route has a wildcard host' do
            before(:each) { object.host = '*' }

            it_behaves_like('an access control', :create, restricted_write_table)
            it_behaves_like('an access control', :delete, restricted_write_table)
            it_behaves_like('an access control', :index, index_table)
            it_behaves_like('an access control', :read, read_table)
            it_behaves_like('an access control', :read_for_update, restricted_write_table)
            it_behaves_like('an access control', :reserved, reserved_table)
            it_behaves_like('an access control', :update, restricted_write_table)
          end

          describe 'when the route does not have a wildcard host' do
            before(:each) { object.host = 'notawildcard' }

            it_behaves_like('an access control', :create, write_table)
            it_behaves_like('an access control', :delete, write_table)
            it_behaves_like('an access control', :index, index_table)
            it_behaves_like('an access control', :read, read_table)
            it_behaves_like('an access control', :read_for_update, write_table)
            it_behaves_like('an access control', :reserved, reserved_table)
            it_behaves_like('an access control', :update, write_table)
          end
        end

        describe 'outside of a shared domain' do
          describe 'when the route has a wildcard host' do
            before(:each) { object.host = '*' }

            it_behaves_like('an access control', :create, write_table)
            it_behaves_like('an access control', :delete, write_table)
            it_behaves_like('an access control', :index, index_table)
            it_behaves_like('an access control', :read, read_table)
            it_behaves_like('an access control', :read_for_update, write_table)
            it_behaves_like('an access control', :reserved, reserved_table)
            it_behaves_like('an access control', :update, write_table)
          end

          describe 'when the route does not have a wildcard host' do
            before(:each) { object.host = 'notawildcard' }

            it_behaves_like('an access control', :create, write_table)
            it_behaves_like('an access control', :delete, write_table)
            it_behaves_like('an access control', :index, index_table)
            it_behaves_like('an access control', :read, read_table)
            it_behaves_like('an access control', :read_for_update, write_table)
            it_behaves_like('an access control', :reserved, reserved_table)
            it_behaves_like('an access control', :update, write_table)
          end
        end
      end

      describe 'when route creation is disabled' do
        describe 'in a shared domain' do
          before(:each) { object.domain = SharedDomain.make }

          describe 'when the route has a wildcard host' do
            before(:each) { object.host = '*' }

            it_behaves_like('a feature flag-disabled access control', :create, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :delete, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :index, index_table)
            it_behaves_like('a feature flag-disabled access control', :read, read_table)
            it_behaves_like('a feature flag-disabled access control', :read_for_update, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :reserved, reserved_table)
            it_behaves_like('a feature flag-disabled access control', :update, restricted_write_table)
          end

          describe 'when the route does not have a wildcard host' do
            before(:each) { object.host = 'notawildcard' }

            it_behaves_like('a feature flag-disabled access control', :create, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :delete, write_table)
            it_behaves_like('a feature flag-disabled access control', :index, index_table)
            it_behaves_like('a feature flag-disabled access control', :read, read_table)
            it_behaves_like('a feature flag-disabled access control', :read_for_update, write_table)
            it_behaves_like('a feature flag-disabled access control', :reserved, reserved_table)
            it_behaves_like('a feature flag-disabled access control', :update, write_table)
          end
        end

        describe 'outside of a shared domain' do
          describe 'when the route has a wildcard host' do
            before(:each) { object.host = '*' }

            it_behaves_like('a feature flag-disabled access control', :create, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :delete, write_table)
            it_behaves_like('a feature flag-disabled access control', :index, index_table)
            it_behaves_like('a feature flag-disabled access control', :read, read_table)
            it_behaves_like('a feature flag-disabled access control', :read_for_update, write_table)
            it_behaves_like('a feature flag-disabled access control', :reserved, reserved_table)
            it_behaves_like('a feature flag-disabled access control', :update, write_table)
          end

          describe 'when the route does not have a wildcard host' do
            before(:each) { object.host = 'notawildcard' }

            it_behaves_like('a feature flag-disabled access control', :create, restricted_write_table)
            it_behaves_like('a feature flag-disabled access control', :delete, write_table)
            it_behaves_like('a feature flag-disabled access control', :index, index_table)
            it_behaves_like('a feature flag-disabled access control', :read, read_table)
            it_behaves_like('a feature flag-disabled access control', :read_for_update, write_table)
            it_behaves_like('a feature flag-disabled access control', :reserved, reserved_table)
            it_behaves_like('a feature flag-disabled access control', :update, write_table)
          end
        end
      end
    end
  end
end
