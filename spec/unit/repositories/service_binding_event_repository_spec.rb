require 'spec_helper'
require 'repositories/service_binding_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe ServiceBindingEventRepository do
      let(:user_guid) { 'user-guid' }
      let(:user_email) { 'some-email' }
      let(:user_name) { 'some-username' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user_guid, user_name: user_name, user_email: user_email) }
      let(:service_binding) { ServiceBinding.make(name: 'some-binding-name') }

      describe '.record_start_create' do
        it 'creates an audit.service_binding.start_create event' do
          request = { 'big' => 'data' }
          event   = ServiceBindingEventRepository.record_start_create(service_binding, user_audit_info, request)

          expect(event.type).to eq('audit.service_binding.start_create')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('some-binding-name')
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
          event   = ServiceBindingEventRepository.record_start_create(service_binding, user_audit_info, request)

          expect(event.metadata[:request]).to eq(
            {
              'big'  => 'data',
              'data' => '[PRIVATE DATA HIDDEN]'
            }
          )
          expect(event.metadata[:manifest_triggered]).to eq(nil)
        end

        context 'when the event is manifest triggered' do
          it 'tags the event as manifest_triggered: true' do
            request = { 'big' => 'data' }
            event   = ServiceBindingEventRepository.record_start_create(service_binding, user_audit_info, request, manifest_triggered: true)

            expect(event.metadata[:manifest_triggered]).to eq(true)
          end
        end

        context 'when binding name is not set' do
          let(:service_binding) { ServiceBinding.make(name: nil) }

          it 'records actee_name as empty' do
            event = ServiceBindingEventRepository.record_start_create(service_binding, user_audit_info, {})
            expect(event.actee_name).to eq('')
          end
        end
      end

      describe '.record_create' do
        it 'creates an audit.service_binding.create event' do
          request = { 'big' => 'data' }
          event   = ServiceBindingEventRepository.record_create(service_binding, user_audit_info, request)

          expect(event.type).to eq('audit.service_binding.create')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('some-binding-name')
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
          event   = ServiceBindingEventRepository.record_create(service_binding, user_audit_info, request)

          expect(event.metadata[:request]).to eq(
            {
              'big'  => 'data',
              'data' => '[PRIVATE DATA HIDDEN]'
            }
          )
          expect(event.metadata[:manifest_triggered]).to eq(nil)
        end

        context 'when the event is manifest triggered' do
          it 'tags the event as manifest_triggered: true' do
            request = { 'big' => 'data' }
            event   = ServiceBindingEventRepository.record_create(service_binding, user_audit_info, request, manifest_triggered: true)

            expect(event.metadata[:manifest_triggered]).to eq(true)
          end
        end

        context 'when binding name is not set' do
          let(:service_binding) { ServiceBinding.make(name: nil) }

          it 'records actee_name as empty' do
            event = ServiceBindingEventRepository.record_create(service_binding, user_audit_info, {})
            expect(event.actee_name).to eq('')
          end
        end
      end

      describe '.record_start_delete' do
        it 'creates an audit.service_binding.start_delete event' do
          event = ServiceBindingEventRepository.record_start_delete(service_binding, user_audit_info)

          expect(event.type).to eq('audit.service_binding.start_delete')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('some-binding-name')
          expect(event.space_guid).to eq(service_binding.space.guid)
          expect(event.organization_guid).to eq(service_binding.space.organization.guid)
          expect(event.metadata).to eq(
            request: {
              app_guid: service_binding.app_guid,
              service_instance_guid: service_binding.service_instance_guid,
            },
          )
        end

        context 'when binding name is not set' do
          let(:service_binding) { ServiceBinding.make(name: nil) }

          it 'records actee_name as empty' do
            event = ServiceBindingEventRepository.record_start_delete(service_binding, user_audit_info)
            expect(event.actee_name).to eq('')
          end
        end
      end

      describe '.record_delete' do
        it 'creates an audit.service_binding.delete event' do
          event = ServiceBindingEventRepository.record_delete(service_binding, user_audit_info)

          expect(event.type).to eq('audit.service_binding.delete')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(service_binding.guid)
          expect(event.actee_type).to eq('service_binding')
          expect(event.actee_name).to eq('some-binding-name')
          expect(event.space_guid).to eq(service_binding.space.guid)
          expect(event.organization_guid).to eq(service_binding.space.organization.guid)
          expect(event.metadata).to eq(
            request: {
              app_guid: service_binding.app_guid,
              service_instance_guid: service_binding.service_instance_guid,
            },
          )
        end

        context 'when binding name is not set' do
          let(:service_binding) { ServiceBinding.make(name: nil) }

          it 'records actee_name as empty' do
            event = ServiceBindingEventRepository.record_delete(service_binding, user_audit_info)
            expect(event.actee_name).to eq('')
          end
        end
      end
    end
  end
end
