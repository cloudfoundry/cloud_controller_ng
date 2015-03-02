require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe RouteEventRepository do
      let(:user) { User.make }
      let(:route) { Route.make }
      let(:user_email) { 'email address' }

      subject(:route_event_repository) { RouteEventRepository.new }

      describe '#record_route_delete' do
        it 'records event correctly' do
          event = route_event_repository.record_route_delete_request(route, user, user_email)
          event.reload
          expect(event.type).to eq('audit.route.delete-request')
          expect(event.actee).to eq(route.guid)
          expect(event.actee_type).to eq('route')
          expect(event.actee_name).to eq(route.fqdn)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.organization_guid).to eq(route.space.organization.guid)
          expect(event.space_guid).to eq(route.space.guid)
        end
      end
    end
  end
end
