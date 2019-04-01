require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe SpaceEventRepository do
      let(:request_attrs) { { 'name' => 'new-space' } }
      let(:user) { User.make }
      let(:space) { Space.make }
      let(:user_email) { 'email address' }
      let(:user_name) { 'user name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user.guid, user_name: user_name) }

      subject(:space_event_repository) { SpaceEventRepository.new }

      describe '#record_space_create' do
        it 'records event correctly' do
          event = space_event_repository.record_space_create(space, user_audit_info, request_attrs)
          event.reload
          expect(event.space).to eq(space)
          expect(event.type).to eq('audit.space.create')
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq('space')
          expect(event.actee_name).to eq(space.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_space_update' do
        it 'records event correctly' do
          event = space_event_repository.record_space_update(space, user_audit_info, request_attrs)
          event.reload
          expect(event.space).to eq(space)
          expect(event.type).to eq('audit.space.update')
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq('space')
          expect(event.actee_name).to eq(space.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_space_delete' do
        let(:recursive) { true }

        before do
          space.destroy
        end

        it 'records event correctly' do
          event = space_event_repository.record_space_delete_request(space, user_audit_info, recursive)
          event.reload
          expect(event.space).to be_nil
          expect(event.type).to eq('audit.space.delete-request')
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq('space')
          expect(event.actee_name).to eq(space.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => { 'recursive' => true } })
        end
      end
    end
  end
end
