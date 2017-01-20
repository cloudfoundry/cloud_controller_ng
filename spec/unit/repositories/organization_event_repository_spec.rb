require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe OrganizationEventRepository do
      let(:request_attrs) { { 'name' => 'new-space' } }
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:user_email) { 'email address' }

      subject(:organization_event_repository) { OrganizationEventRepository.new }

      describe '#record_organization_create' do
        it 'records event correctly' do
          event = organization_event_repository.record_organization_create(organization, user, user_email, request_attrs)
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

        context 'when the user email is unknown' do
          it 'leaves actor name empty' do
            event = organization_event_repository.record_organization_create(organization, user, nil, request_attrs)
            event.reload
            expect(event.actor_name).to eq(nil)
          end
        end
      end

      describe '#record_organization_update' do
        it 'records event correctly' do
          event = organization_event_repository.record_organization_update(organization, user, user_email, request_attrs)
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
          event = organization_event_repository.record_organization_delete_request(organization, user, user_email, request_attrs)
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
