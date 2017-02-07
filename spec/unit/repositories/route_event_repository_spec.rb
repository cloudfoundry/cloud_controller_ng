require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe RouteEventRepository do
      let(:user) { User.make }
      let(:route) { Route.make }
      let(:request_attrs) { { 'host' => 'dora', 'domain_guid' => route.domain.guid, 'space_guid' => route.space.guid } }
      let(:user_email) { 'some@email.com' }
      let(:user_name) { 'some-user' }
      let(:actor_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_name: user_name, user_email: user_email) }

      subject(:route_event_repository) { RouteEventRepository.new }

      describe '#record_route_create' do
        it 'records event correctly' do
          event = route_event_repository.record_route_create(route, actor_audit_info, request_attrs)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.create')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_route_update' do
        it 'records event correctly' do
          event = route_event_repository.record_route_update(route, actor_audit_info, request_attrs)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.update')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.metadata).to eq({ 'request' => request_attrs })
        end
      end

      describe '#record_route_delete' do
        let(:recursive) { true }

        before do
          route.destroy
        end

        it 'records event correctly' do
          event = route_event_repository.record_route_delete_request(route, actor_audit_info, recursive)
          event.reload
          expect(event.space).to eq(route.space)
          expect(event.type).to eq('audit.route.delete-request')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.host)
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
