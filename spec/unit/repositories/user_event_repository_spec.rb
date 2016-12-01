require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe UserEventRepository do
      let(:request_attrs) { { 'name' => 'new-space' } }
      let(:user) { User.make }
      let(:space) { Space.make }
      let(:user_email) { 'email address' }

      #   subject { UserEventRepository.new }

      describe 'role events' do
        let(:assigner) { User.make }
        let(:assignee) { User.make(username: 'frank') }
        let(:assigner_email) { 'foo@bar.com' }
        let(:roles) { [:manager, :developer, :auditor] }
        let(:request_attrs) { { 'some_key' => 'some_val' } }

        describe '#record_space_role_add' do
          it 'records the event correctly' do
            roles.each do |role|
              event = subject.record_space_role_add(space, assignee, role, assigner, assigner_email, request_attrs)
              event.reload
              expect(event.space).to eq(space)
              expect(event.type).to eq("audit.user.space_#{role}_add")
              expect(event.actee).to eq(assignee.guid)
              expect(event.actee_type).to eq('user')
              expect(event.actee_name).to eq(assignee.username)
              expect(event.actor).to eq(assigner.guid)
              expect(event.actor_type).to eq('user')
              expect(event.actor_name).to eq(assigner_email)
              expect(event.metadata).to eq({ 'request' => request_attrs })
            end
          end
        end

        describe '#record_space_role_remove' do
          it 'records the event correctly' do
            roles.each do |role|
              event = subject.record_space_role_remove(space, assignee, role, assigner, assigner_email, request_attrs)
              event.reload
              expect(event.space).to eq(space)
              expect(event.type).to eq("audit.user.space_#{role}_remove")
              expect(event.actee).to eq(assignee.guid)
              expect(event.actee_type).to eq('user')
              expect(event.actee_name).to eq(assignee.username)
              expect(event.actor).to eq(assigner.guid)
              expect(event.actor_type).to eq('user')
              expect(event.actor_name).to eq(assigner_email)
              expect(event.metadata).to eq({ 'request' => request_attrs })
            end
          end
        end
      end
    end
  end
end
