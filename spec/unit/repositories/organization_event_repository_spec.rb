require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe OrganizationEventRepository do
      let(:request_attrs) { { 'name' => 'new-space' } }
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:user_email) { 'email address' }
      let(:user_name) { 'user name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user.guid, user_name: user_name) }

          subject(:organization_event_repository) { OrganizationEventRepository.new }

      describe '#record_organization_create' do
        it 'records event correctly' do
          event = organization_event_repository.record_organization_create(organization, user_audit_info, request_attrs)
          event.reload
          expect(event.organization_guid).to eq(organization.guid)
          expect(event.type).to eq('audit.organization.create')
          expect(event.actee).to eq(organization.guid)
          expect(event.actee_type).to eq('organization')
          expect(event.actee_name).to eq(organization.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_organization_update' do
        it 'records event correctly' do
          event = organization_event_repository.record_organization_update(organization, user_audit_info, request_attrs)
          event.reload
          expect(event.organization_guid).to eq(organization.guid)
          expect(event.type).to eq('audit.organization.update')
          expect(event.actee).to eq(organization.guid)
          expect(event.actee_type).to eq('organization')
          expect(event.actee_name).to eq(organization.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_organization_delete' do
        let(:recursive) { true }

        before do
          organization.destroy
        end

        it 'records event correctly' do
          event = organization_event_repository.record_organization_delete_request(organization, user_audit_info, request_attrs)
          event.reload
          expect(event.organization_guid).to eq(organization.guid)
          expect(event.type).to eq('audit.organization.delete-request')
          expect(event.actee).to eq(organization.guid)
          expect(event.actee_type).to eq('organization')
          expect(event.actee_name).to eq(organization.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end
    end
  end
end
