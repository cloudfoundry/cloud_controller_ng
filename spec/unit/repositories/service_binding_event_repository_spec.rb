require 'spec_helper'
require 'repositories/service_binding_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe ServiceBindingEventRepository do
      let(:user_guid) { 'user-guid' }
      let(:user_email) { 'user@example.com' }
      let(:service_binding) { ServiceBindingModel.make }

      describe '.record_create' do
        it 'creates an audit.service_binding.create event' do
          request = { 'big' => 'data' }
          event   = ServiceBindingEventRepository.record_create(service_binding, user_guid, user_email, request)

          expect(event.type).to eq('audit.service_binding.create')
          expect(event.actor).to eq('user-guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('v3-service-binding')
          expect(event.actee_name).to eq('')
          expect(event.space_guid).to eq(service_binding.space.guid)
          expect(event.organization_guid).to eq(service_binding.space.organization.guid)
          expect(event.metadata[:request]).to eq(
            {
              'big' => 'data'
            }
          )
        end

        it 'censors metadata.request.data' do
          request = { 'big' => 'data', 'data' => 'lake', :data => 'tolerates symbols' }
          event   = ServiceBindingEventRepository.record_create(service_binding, user_guid, user_email, request)

          expect(event.metadata[:request]).to eq(
            {
              'big'  => 'data',
              'data' => 'PRIVATE DATA HIDDEN'
            }
          )
        end
      end

      describe '.record_delete' do
        it 'creates an audit.service_binding.delete event' do
          event = ServiceBindingEventRepository.record_delete(service_binding, user_guid, user_email)

          expect(event.type).to eq('audit.service_binding.delete')
          expect(event.actor).to eq('user-guid')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('v3-service-binding')
          expect(event.actee_name).to eq('')
          expect(event.space_guid).to eq(service_binding.space.guid)
          expect(event.organization_guid).to eq(service_binding.space.organization.guid)
          expect(event.metadata).to eq({})
        end
      end
    end
  end
end
