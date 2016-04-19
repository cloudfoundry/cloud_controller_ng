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
    end
  end
end
