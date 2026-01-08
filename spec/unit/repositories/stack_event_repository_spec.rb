require 'spec_helper'
require 'repositories/stack_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe StackEventRepository do
      let(:request_attrs) { { 'name' => 'new-stack' } }
      let(:user) { User.make }
      let(:stack) { Stack.make }
      let(:user_email) { 'email address' }
      let(:user_name) { 'user name' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user.guid, user_name: user_name) }

      subject(:stack_event_repository) { StackEventRepository.new }

      describe '#record_stack_create' do
        it 'records event correctly' do
          event = stack_event_repository.record_stack_create(stack, user_audit_info, request_attrs)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.stack.create')
          expect(event.actee).to eq(stack.guid)
          expect(event.actee_type).to eq('stack')
          expect(event.actee_name).to eq(stack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_stack_update' do
        it 'records event correctly' do
          event = stack_event_repository.record_stack_update(stack, user_audit_info, request_attrs)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.stack.update')
          expect(event.actee).to eq(stack.guid)
          expect(event.actee_type).to eq('stack')
          expect(event.actee_name).to eq(stack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_stack_delete' do
        it 'records event correctly' do
          event = stack_event_repository.record_stack_delete(stack, user_audit_info)
          event.reload
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.type).to eq('audit.stack.delete')
          expect(event.actee).to eq(stack.guid)
          expect(event.actee_type).to eq('stack')
          expect(event.actee_name).to eq(stack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({})
        end
      end
    end
  end
end
