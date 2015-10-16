require 'spec_helper'

module VCAP::CloudController
  describe UserProvidedServiceInstancesController, :services do
    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
              name:                  { type: 'string', required: true },
              credentials:           { type: 'hash', default: {} },
              syslog_drain_url:      { type: 'string', default: '' },
              space_guid:            { type: 'string', required: true },
              service_binding_guids: { type: '[string]' },
              route_service_url:     { type: 'string', default: '' },
              route_guids: { type: '[string]' },
            })
      end

      it do
        expect(described_class).to have_updatable_attributes({
              name:                  { type: 'string' },
              credentials:           { type: 'hash' },
              syslog_drain_url:      { type: 'string' },
              space_guid:            { type: 'string' },
              service_binding_guids: { type: '[string]' },
              route_service_url:     { type: 'string' },
              route_guids: { type: '[string]' },
            })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = UserProvidedServiceInstance.make(space: @space_a)
        @obj_b = UserProvidedServiceInstance.make(space: @space_b)
      end

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples 'permission enumeration', user_role,
            name:      'user provided service instance',
            path:      '/v2/user_provided_service_instances',
            enumerate: 0
        end
      end

      describe 'Org Level Permissions' do
        user_sees_empty_enumerate('OrgManager', :@org_a_manager, :@org_b_manager)
        user_sees_empty_enumerate('OrgUser', :@org_a_member, :@org_b_member)
        user_sees_empty_enumerate('BillingManager', :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate('Auditor', :@org_a_auditor, :@org_b_auditor)
      end

      describe 'App Space Level Permissions' do
        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
            name:      'user provided service instance',
            path:      '/v2/user_provided_service_instances',
            enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
            name:      'user provided service instance',
            path:      '/v2/user_provided_service_instances',
            enumerate: 1
        end

        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name:      'user provided service instance',
            path:      '/v2/user_provided_service_instances',
            enumerate: 1
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes(
            service_bindings: [:get, :put, :delete],
            routes: [:get, :put, :delete]
          )
      end
    end

    describe 'POST', '/v2/user_provided_service_instances' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let(:req) do
        {
          'name'              => 'my-upsi',
          'credentials'       => { 'uri' => 'https://user:password@service-location.com:port/db' },
          'space_guid'        => space.guid,
          'route_service_url' => 'https://route.url.com'
        }
      end

      it 'creates a user provided service instance' do
        post '/v2/user_provided_service_instances', req.to_json, headers_for(developer)

        expect(last_response.status).to eq 201

        service_instance = UserProvidedServiceInstance.first
        expect(service_instance.name).to eq 'my-upsi'
        expect(service_instance.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        expect(service_instance.space.guid).to eq space.guid
        expect(service_instance.route_service_url).to eq 'https://route.url.com'
      end

      it 'records a create event' do
        post '/v2/user_provided_service_instances', req.to_json, headers_for(developer, email: email)

        event            = Event.first(type: 'audit.user_provided_service_instance.create')
        service_instance = UserProvidedServiceInstance.first

        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({
              'request' => {
                'name'              => 'my-upsi',
                'credentials'       => '[REDACTED]',
                'space_guid'        => space.guid,
                'syslog_drain_url'  => '',
                'route_service_url' => 'https://route.url.com'
              }
            })
      end

      context 'when the service instance is invalid' do
        context 'because the route_service_url is invalid' do
          let(:req) do
            {
              'name'              => 'my-upsi',
              'credentials'       => { 'uri' => 'https://user:password@service-location.com:port/db' },
              'space_guid'        => space.guid,
              'route_service_url' => 'http://route.url.com'
            }
          end

          it 'returns CF-ServiceInstanceInvalid' do
            post '/v2/user_provided_service_instances', req.to_json, headers_for(developer)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['error_code']).to eq('CF-ServiceInstanceRouteServiceURLInvalid')
            expect(decoded_response['description']).to include 'must be https'
          end
        end
      end
    end

    describe 'PUT', '/v2/user_provided_service_instances/:guid' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let(:req) do
        {
          'name'        => 'my-upsi',
          'credentials' => { 'uri' => 'https://user:password@service-location.com:port/db' }
        }
      end

      let!(:service_instance) { UserProvidedServiceInstance.make(space: space) }

      it 'updates the user provided service instance' do
        put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer)

        expect(last_response.status).to eq 201

        service_instance = UserProvidedServiceInstance.first
        expect(service_instance.name).to eq 'my-upsi'
        expect(service_instance.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        expect(service_instance.space.guid).to eq space.guid
      end

      it 'records a update event' do
        put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer, email: email)

        service_instance = UserProvidedServiceInstance.first
        event            = Event.first(type: 'audit.user_provided_service_instance.update')

        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({
              'request' => {
                'name'        => 'my-upsi',
                'credentials' => '[REDACTED]'
              }
            })
      end

      describe 'the space_guid parameter' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:developer) { make_developer_for_space(space) }
        let(:instance) { UserProvidedServiceInstance.make(space: space) }

        it 'prevents a developer from moving the service instance to a space for which he is also a space developer' do
          space2 = Space.make(organization: org)
          space2.add_developer(developer)

          move_req = MultiJson.dump(
            space_guid: space2.guid,
          )

          put "/v2/user_provided_service_instances/#{instance.guid}", move_req, headers_for(developer)

          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match /cannot change space for service instance/
        end

        it 'succeeds when the space_guid does not change' do
          req = MultiJson.dump(space_guid: instance.space.guid)
          put "/v2/user_provided_service_instances/#{instance.guid}", req, headers_for(developer)
          expect(last_response.status).to eq 201
        end

        it 'succeeds when the space_guid is not provided' do
          put "/v2/user_provided_service_instances/#{instance.guid}", {}.to_json, headers_for(developer)
          expect(last_response.status).to eq 201
        end
      end

      context 'when the service instance has a binding' do
        let!(:binding) { ServiceBinding.make service_instance: service_instance }

        it 'propagates the updated credentials to the binding' do
          put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer)

          expect(binding.reload.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        end
      end
    end

    describe 'DELETE', '/v2/user_provided_service_instances/:guid' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let!(:service_instance) { UserProvidedServiceInstance.make(space: space) }

      it 'deletes the user provided service instance' do
        expect(UserProvidedServiceInstance.all.count).to eq 1
        delete "/v2/user_provided_service_instances/#{service_instance.guid}", {}, headers_for(developer)

        expect(last_response).to have_status_code(204)

        expect(UserProvidedServiceInstance.all.count).to eq 0
      end

      it 'records a create event' do
        service_instance = UserProvidedServiceInstance.first

        delete "/v2/user_provided_service_instances/#{service_instance.guid}", {}, headers_for(developer, email: email)
        event = Event.first(type: 'audit.user_provided_service_instance.delete')
        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({ 'request' => {} })
      end
    end

    describe 'PUT', '/v2/user_provided_service_instances/:guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:route) { VCAP::CloudController::Route.make(space: space) }
      let(:opts) { {} }
      let(:service_instance) { UserProvidedServiceInstance.make(:routing, space: space) }

      it 'associates the route and the service instance' do
        get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['total_results']).to eql(0)

        put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
        expect(last_response.status).to eq(201)

        get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['total_results']).to eql(1)
      end

      context 'when the route is mapped to a non-diego app' do
        before do
          app = AppFactory.make(diego: false, space: route.space, state: 'STARTED')
          app.add_route(route)
        end

        it 'raises RouteServiceRequiresDiego' do
          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to eq('Route services are only supported for apps on Diego. Unbind the service instance from the route or enable Diego for the app.')
        end

        context 'and is mapped to a diego app' do
          before do
            diego_app = AppFactory.make(diego: true, space: route.space, state: 'STARTED')
            diego_app.add_route(route)
          end

          it 'raises RouteServiceRequiresDiego' do
            put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)

            expect(last_response.status).to eq(400)

            expect(JSON.parse(last_response.body)['description']).
              to eq('Route services are only supported for apps on Diego. Unbind the service instance from the route or enable Diego for the app.')
          end
        end
      end
      context 'binding permissions' do
        context 'admin' do
          it 'allows an admin to bind a space' do
            put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, admin_headers
            expect(last_response.status).to eq(201)
          end
        end

        context 'space developer' do
          it 'allows a developer to bind a space' do
            put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
            expect(last_response.status).to eq(201)
          end
        end

        context 'neither an admin nor a Space Developer' do
          let(:manager) { make_manager_for_space(space) }

          it 'raises an error' do
            put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(manager)
            expect(last_response.status).to eq(403)
            expect(last_response.body).to include('You are not authorized to perform the requested action')
          end
        end
      end

      context 'when the route does not exist' do
        it 'raises an error' do
          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/random-guid", {}, headers_for(developer)
          expect(last_response.status).to eq(404)
          expect(JSON.parse(last_response.body)['description']).
            to include('route could not be found')
        end
      end

      context 'when the route has an associated service instance' do
        before do
          service_instance = UserProvidedServiceInstance.make(:routing, space: space)
          RouteBinding.make service_instance: service_instance, route: route
        end

        it 'raises RouteAlreadyBoundToServiceInstance' do
          get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)

          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to eq('A route may only be bound to a single service instance')

          get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)
        end
      end

      context 'when attempting to bind to a service with no route_service_url' do
        before do
          service_instance = UserProvidedServiceInstance.make(space: space)
          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
        end

        it 'raises ServiceDoesNotSupportRoutes error' do
          expect(decoded_response['error_code']).to eq('CF-ServiceDoesNotSupportRoutes')
          expect(last_response).to have_status_code(400)
        end
      end

      context 'when attempting to bind to a service with an empty route_service_url' do
        before do
          service_instance = UserProvidedServiceInstance.make(route_service_url: '', space: space)
          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
        end

        it 'raises ServiceDoesNotSupportRoutes error' do
          expect(last_response).to have_status_code(400)
          expect(decoded_response['error_code']).to eq('CF-ServiceDoesNotSupportRoutes')
        end
      end

      context 'when the route and service_instance are not in the same space' do
        let(:other_space) { Space.make(organization: space.organization) }
        let(:service_instance) { UserProvidedServiceInstance.make(:routing, space: other_space) }

        before do
          other_space.add_developer(developer)
          other_space.save
        end

        it 'raises an error' do
          put "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['description']).
            to include('The service instance and the route are in different spaces.')
        end
      end
    end

    describe 'DELETE', '/v2/user_provided_service_instances/:service_instance_guid/routes/:route_guid' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:service_instance) { UserProvidedServiceInstance.make(:routing, space: space) }
      let(:route) { Route.make(space: space) }

      context 'when a service has an associated route' do
        let!(:route_binding) { RouteBinding.make(route: route, service_instance: service_instance) }

        it 'deletes the association between the route and the service instance' do
          get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
          expect(last_response).to have_status_code(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(1)

          delete "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
          expect(last_response).to have_status_code(204)
          expect(last_response.body).to be_empty

          get "/v2/user_provided_service_instances/#{service_instance.guid}/routes", {}, headers_for(developer)
          expect(last_response).to have_status_code(200)
          expect(JSON.parse(last_response.body)['total_results']).to eql(0)
        end
      end

      context 'when the service_instance does not exist' do
        it 'returns a 404' do
          delete "/v2/user_provided_service_instances/fake-guid/routes/#{route.guid}", {}, headers_for(developer)
          expect(last_response).to have_status_code(404)
        end
      end

      context 'when the route does not exist' do
        it 'returns a 404' do
          delete "/v2/user_provided_service_instances/#{service_instance.guid}/routes/fake-guid", {}, headers_for(developer)
          expect(last_response).to have_status_code(404)
        end
      end

      context 'when the route and service are not bound' do
        it 'returns a 400 InvalidRelation error' do
          delete "/v2/user_provided_service_instances/#{service_instance.guid}/routes/#{route.guid}", {}, headers_for(developer)
          expect(last_response).to have_status_code(400)
          expect(JSON.parse(last_response.body)['description']).to include('Invalid relation')
        end
      end
    end
  end
end
