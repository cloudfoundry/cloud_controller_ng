require 'spec_helper'
require 'repositories/runtime/process_event_repository'

module VCAP::CloudController
  module Repositories::Runtime
    describe ProcessEventRepository do
      let(:app) { AppModel.make(name: 'potato') }
      let(:process) { App.make(app: app, space: app.space, type: 'potato') }
      let(:user_guid) { 'user_guid' }
      let(:email) { 'user-email' }

      describe '.record_create' do
        it 'creates a new audit.app.start event' do
          event = ProcessEventRepository.record_create(process, user_guid, email)
          event.reload

          expect(event.type).to eq('audit.app.process.create')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          expect(event.metadata).to eq({
            'process_guid' => process.guid,
            'process_type' => 'potato'
          })
        end
      end

      describe '.record_delete' do
        it 'creates a new audit.app.delete event' do
          event = ProcessEventRepository.record_delete(process, user_guid, email)
          event.reload

          expect(event.type).to eq('audit.app.process.delete')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          expect(event.metadata).to eq({
            'process_guid' => process.guid,
            'process_type' => 'potato'
          })
        end
      end

      describe '.record_scale' do
        it 'creates a new audit.app.delete event' do
          request = { instances: 10, memory_in_mb: 512, disk_in_mb: 2048 }
          event = ProcessEventRepository.record_scale(process, user_guid, email, request)
          event.reload

          expect(event.type).to eq('audit.app.process.scale')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          expect(event.metadata).to eq({
            'process_guid' => process.guid,
            'process_type' => 'potato',
            'request' => {
               'instances' => 10,
               'memory_in_mb' => 512,
               'disk_in_mb' => 2048
            }
          })
        end
      end

      describe '.record_update' do
        it 'creates a new audit.app.update event' do
          event = ProcessEventRepository.record_update(process, user_guid, email, { anything: 'whatever' })
          event.reload

          expect(event.type).to eq('audit.app.process.update')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          expect(event.metadata).to eq({
            'process_guid' => process.guid,
            'process_type' => 'potato',
            'request' => {
              'anything' => 'whatever'
            }
          })
        end

        it 'redacts metadata.request.command' do
          event = ProcessEventRepository.record_update(process, user_guid, email, { command: 'censor this' })
          event.reload

          expect(event.metadata).to match(hash_including(
                                            'request' => {
                                              'command' => 'PRIVATE DATA HIDDEN'
                                            }
          ))
        end
      end

      describe '.record_terminate' do
        it 'creates a new audit.app.terminate_instance event' do
          index = 0
          event = ProcessEventRepository.record_terminate(process, user_guid, email, index)
          event.reload

          expect(event.type).to eq('audit.app.process.terminate_instance')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq('potato')
          expect(event.space_guid).to eq(app.space.guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)

          expect(event.metadata).to eq({
            'process_guid' => process.guid,
            'process_type' => 'potato',
            'process_index' => 0
          })
        end

        it 'redacts metadata.request.command' do
          event = ProcessEventRepository.record_update(process, user_guid, email, { command: 'censor this' })
          event.reload

          expect(event.metadata).to match(hash_including(
                                            'request' => {
                                              'command' => 'PRIVATE DATA HIDDEN'
                                            }
          ))
        end
      end
    end
  end
end
