require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RoutesController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:host) }
      it { expect(described_class).to be_queryable_by(:domain_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:path) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
                                                                 host:        { type: 'string', default: '' },
                                                                 domain_guid: { type: 'string', required: true },
                                                                 space_guid:  { type: 'string', required: true },
                                                                 app_guids:   { type: '[string]' },
                                                                 path:        { type: 'string' },
                                                                 port:        { type: 'integer' }
                                                             })
      end

      it do
        expect(described_class).to have_updatable_attributes({
                                                                 host:        { type: 'string' },
                                                                 domain_guid: { type: 'string' },
                                                                 space_guid:  { type: 'string' },
                                                                 app_guids:   { type: '[string]' },
                                                                 path:        { type: 'string' },
                                                                 port:        { type: 'integer' }
                                                             })
      end
    end

    describe 'Permissions' do
      context 'with a custom domain' do
        include_context 'permissions'

        before do
          @domain_a = PrivateDomain.make(owning_organization: @org_a)
          @obj_a    = Route.make(domain: @domain_a, space: @space_a)

          @domain_b = PrivateDomain.make(owning_organization: @org_b)
          @obj_b    = Route.make(domain: @domain_b, space: @space_b)
        end

        describe 'Org Level Permissions' do
          describe 'OrgManager' do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples 'permission enumeration', 'OrgManager',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 1
          end

          describe 'OrgUser' do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples 'permission enumeration', 'OrgUser',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 0
          end

          describe 'BillingManager' do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples 'permission enumeration', 'BillingManager',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 0
          end

          describe 'Auditor' do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples 'permission enumeration', 'Auditor',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 1
          end
        end

        describe 'App Space Level Permissions' do
          describe 'SpaceManager' do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples 'permission enumeration', 'SpaceManager',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 1
          end

          describe 'Developer' do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples 'permission enumeration', 'Developer',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 1
          end

          describe 'SpaceAuditor' do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples 'permission enumeration', 'SpaceAuditor',
                             name: 'route',
                             path: '/v2/routes',
                             enumerate: 1
          end
        end
      end
    end

    describe 'Validation messages' do
      let(:tcp_domain) { SharedDomain.make(router_group_guid: 'tcp-guid') }
      let(:domain) { SharedDomain.make }
      let(:space) { Space.make }

      let(:routing_api_client) { double('routing_api_client') }
      let(:router_group) {
        RoutingApi::RouterGroup.new({
                                        'guid' => 'tcp-guid',
                                        'type' => 'tcp',
                                    })
      }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                                                                  and_return(routing_api_client)
        allow(routing_api_client).to receive(:router_group).and_return(router_group)
      end

      it 'returns the RouteHostTaken message when no paths are used' do
        taken_host = 'someroute'
        Route.make(host: taken_host, domain: domain)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response).to have_status_code(400)
        expect(decoded_response['code']).to eq(210003)
      end

      it 'returns the RoutePortTaken message when ports conflict' do
        taken_port = 1
        post '/v2/routes', MultiJson.dump(host: '', domain_guid: tcp_domain.guid, space_guid: space.guid, port: taken_port), json_headers(admin_headers)

        post '/v2/routes', MultiJson.dump(host: '', domain_guid: tcp_domain.guid, space_guid: space.guid, port: taken_port), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210005)
      end

      it 'returns the RoutePathTaken message when paths conflict' do
        taken_host = 'someroute'
        path = '/%2Fsome%20path'
        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210004)
      end

      it 'returns the SpaceQuotaTotalRoutesExceeded message' do
        quota_definition = SpaceQuotaDefinition.make(total_routes: 0, organization: space.organization)
        space.space_quota_definition = quota_definition
        space.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310005)
      end

      it 'returns the OrgQuotaTotalRoutesExceeded message' do
        quota_definition = space.organization.quota_definition
        quota_definition.total_routes = 0
        quota_definition.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310006)
      end

      it 'returns the RouteInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample!*', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210001)
      end

      it 'returns the a path cannot contain only "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path cannot be a single slash')
      end

      it 'returns the a path must start with a "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: 'a/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path must start with a "/"')
      end

      it 'returns the a path cannot contain "?" message for paths' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('illegal "?" character')
      end

      it 'returns the PathInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
      end

      it 'does not allow port values below 1' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: tcp_domain.guid, space_guid: space.guid, port: -1), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to include('Port must be greater than 0 and less than 65536.')
      end

      it 'does not allow port values above 65535' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: tcp_domain.guid, space_guid: space.guid, port: 65536), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to include('Port must be greater than 0 and less than 65536.')
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ apps: [:get, :put, :delete] })
      end

      context 'with Docker app' do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let(:organization) { Organization.make }
        let(:domain) { PrivateDomain.make(owning_organization: organization) }
        let(:space) { Space.make(organization: organization) }
        let(:route) { Route.make(domain: domain, space: space) }
        let!(:docker_app) do
          AppFactory.make(space: space, docker_image: 'some-image', state: 'STARTED')
        end

        context 'and Docker disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          it 'associates the route with the app' do
            put "/v2/routes/#{route.guid}/apps/#{docker_app.guid}", MultiJson.dump(guid: route.guid), json_headers(admin_headers)
            expect(last_response.status).to eq(201)
          end
        end
      end
    end

    describe 'DELETE /v2/routes/:guid' do
      context 'with route services bound to the route' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }

        context 'with recursive=true' do
          before do
            stub_unbind(route_binding)
          end

          it 'deletes the route and associated binding' do
            delete "v2/routes/#{route.guid}?recursive=true", {}, admin_headers

            expect(Route.find(guid: route.guid)).not_to be
            expect(RouteBinding.find(guid: route_binding.guid)).not_to be
          end
        end

        context 'without recursive=true' do
          it 'raises an error and does not delete anything' do
            delete "v2/routes/#{route.guid}", {}, admin_headers

            expect(last_response).to have_status_code 400
            expect(last_response.body).to include 'AssociationNotEmpty'
            expect(last_response.body).to include
            'Please delete the service_instance associations for your routes'
          end
        end
      end
    end

    describe 'POST /v2/routes' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:req) {{
          domain_guid: SharedDomain.make.guid,
          space_guid:  space.guid,
          host:        'example'
      }}

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when non-existent domain is specified' do
        let(:req) {{
            domain_guid: 'non-existent-domain',
            space_guid:  space.guid,
            host:        'example',
        }}

        it 'returns an error' do
          post '/v2/routes', MultiJson.dump(req), headers_for(user)

          expect(last_response).to have_status_code(400)
          expect(decoded_response['description']).to include('Domain with guid non-existent-domain does not exist')
        end
      end

      context 'when creating a route with a null port value' do
        let(:domain) { SharedDomain.make(router_group_guid: 'tcp-group') }
        let(:req) {{
            domain_guid: domain.guid,
            space_guid:  space.guid,
            host:        'example',
        }}

        context 'with a tcp domain' do
          it 'returns an error' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Router groups are only supported for TCP routes.')
          end
        end
      end

      context 'when creating a route with a port value that is not null' do
        let(:routing_api_client) { double('routing_api_client') }
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                                                                    and_return(routing_api_client)
          allow(routing_api_client).to receive(:router_groups).and_return(router_groups)
          allow(routing_api_client).to receive(:router_group).and_return(router_groups[0])
        end

        let(:router_groups) do
          [
            RoutingApi::RouterGroup.new({ 'guid' => 'tcp-group', 'type' => 'tcp' }),
            RoutingApi::RouterGroup.new({ 'guid' => 'http-group', 'type' => 'http' }),
          ]
        end

        let(:domain) { SharedDomain.make }
        let(:port) { 10000 }
        let(:req) {{
            domain_guid: domain.guid,
            space_guid:  space.guid,
            host:        'example',
            port:        port,
        }}

        context 'when router_group returns nil' do
          let(:domain) { SharedDomain.make(router_group_guid: 'another-group') }

          before do
            allow(routing_api_client).to receive(:router_group).and_return(nil)
          end

          it 'rejects the request with a RouteInvalid error' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
          end
        end

        context 'with a domain with a router_group_guid and type tcp' do
          let(:domain) { SharedDomain.make(router_group_guid: 'tcp-group') }

          it 'creates the route' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(201)
            expect(decoded_response['entity']['port']).to eq(port)
          end

          context 'with an invalid port' do
            let(:port) { 0 }
            it 'verifies that port is greater than 0' do
              post '/v2/routes', MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('Port must be greater than 0 and less than 65536.')
            end
          end
        end

        context 'with a domain without a router_group_guid' do
          it 'rejects the request with a RouteInvalid error' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
          end
        end

        context 'with a domain with a router_group_guid of type other than tcp' do
          let(:domain) { SharedDomain.make(router_group_guid: 'http-group') }

          before do
            allow(routing_api_client).to receive(:router_group).and_return(router_groups[1])
          end

          it 'rejects the request with a RouteInvalid error' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
          end
        end

        context 'when the routing api client raises a UaaUnavailable error' do
          let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
          before do
            allow(routing_api_client).to receive(:router_group).
                                             and_raise(RoutingApi::Client::UaaUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'The UAA service is currently unavailable'
          end
        end

        context 'when the routing api client raises a RoutingApiUnavailable error' do
          let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
          before do
            allow(routing_api_client).to receive(:router_group).
                                             and_raise(RoutingApi::Client::RoutingApiUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'Routing API is currently unavailable'
          end
        end
      end

      context 'when route_creation feature flag is disabled' do
        before { FeatureFlag.make(name: 'route_creation', enabled: false, error_message: nil) }

        it 'returns FeatureDisabled for users' do
          post '/v2/routes', MultiJson.dump(req), headers_for(user)

          expect(last_response.status).to eq(403)
          expect(decoded_response['error_code']).to match(/FeatureDisabled/)
          expect(decoded_response['description']).to match(/route_creation/)
        end
      end
    end

    describe 'PUT /v2/routes/:guid' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:domain) { SharedDomain.make }
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      describe 'tcp routes' do
        let(:port) { 18000 }
        let(:route) { Route.make(space: space, domain: domain, port: port) }
        let(:routing_api_client) { double('routing_api_client') }
        let(:router_groups) do
          [
            RoutingApi::RouterGroup.new({ 'guid' => 'tcp-group', 'type' => 'tcp' }),
            RoutingApi::RouterGroup.new({ 'guid' => 'http-group', 'type' => 'http' }),
          ]
        end

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                                                                    and_return(routing_api_client)
          allow(routing_api_client).to receive(:router_groups).and_return(router_groups)
          allow(routing_api_client).to receive(:router_group).and_return(router_groups[0])
        end

        context 'when associating with app' do
          let(:domain) { SharedDomain.make(router_group_guid: 'tcp-group') }
          let(:req) { '' }
          let(:app_obj) { AppFactory.make(space: route.space) }

          it 'allows updating route' do
            put "/v2/routes/#{route.guid}/apps/#{app_obj.guid}", MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(201)
            expect(app_obj.reload.routes.first).to eq(route)
          end
        end

        context 'when updating a route with a port value that is not null' do
          let(:req) {{
              port: port,
          }}

          context 'when router_group returns nil' do
            let(:domain) { SharedDomain.make(router_group_guid: 'tcp-group') }

            before do
              allow(routing_api_client).to receive(:router_group).and_return(nil)
            end

            it 'rejects the request with a RouteInvalid error' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
            end
          end

          context 'with a domain with a router_group_guid and type tcp' do
            let(:port) { 20000 }
            let(:domain) { SharedDomain.make(router_group_guid: 'tcp-group') }

            it 'creates the route' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['port']).to eq(port)
            end

            context 'with an invalid port' do
              let(:port) { 0 }
              it 'verifies that port is greater than 0' do
                put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

                expect(last_response).to have_status_code(400)
                expect(decoded_response['description']).to include('Port must be greater than 0 and less than 65536.')
              end
            end
          end

          context 'with a domain without a router_group_guid' do
            it 'rejects the request with a RouteInvalid error' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
            end
          end

          context 'with a domain with a router_group_guid of type other than tcp' do
            let(:domain) { SharedDomain.make(router_group_guid: 'http-group') }

            before do
              allow(routing_api_client).to receive(:router_group).and_return(router_groups[1])
            end

            it 'rejects the request with a RouteInvalid error' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(400)
              expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only.')
            end
          end

          context 'when the routing api client raises a UaaUnavailable error' do
            let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
            before do
              allow(routing_api_client).to receive(:router_group).
                                               and_raise(RoutingApi::Client::UaaUnavailable)
            end

            it 'returns a 503 Service Unavailable' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(503)
              expect(last_response.body).to include 'The UAA service is currently unavailable'
            end
          end

          context 'when the routing api client raises a RoutingApiUnavailable error' do
            let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
            before do
              allow(routing_api_client).to receive(:router_group).
                                               and_raise(RoutingApi::Client::RoutingApiUnavailable)
            end

            it 'returns a 503 Service Unavailable' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(503)
              expect(last_response.body).to include 'Routing API is currently unavailable'
            end
          end
        end
      end
    end

    describe 'GET /v2/routes/:guid' do
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:domain) { PrivateDomain.make(owning_organization: organization) }
      let(:space) { Space.make(organization: organization) }
      let(:route) { Route.make(domain: domain, space: space) }

      context 'as a space auditor' do
        before do
          organization.add_user user
          space.add_auditor user
        end

        it 'includes the domain guid' do
          get "/v2/routes/#{route.guid}", {}, headers_for(user)
          expect(last_response.status).to eq 200
          expect(decoded_response['entity']['domain_guid']).to_not be_nil
        end
      end

      context 'as an admin' do
        it 'includes the domain guid' do
          get "/v2/routes/#{route.guid}", {}, admin_headers
          expect(last_response.status).to eq 200
          expect(decoded_response['entity']['domain_guid']).to_not be_nil
        end
      end
    end

    describe 'GET /v2/routes' do
      let(:organization) { Organization.make }
      let(:domain) { PrivateDomain.make(owning_organization: organization) }
      let(:space) { Space.make(organization: organization) }
      let(:route) { Route.make(domain: domain, space: space) }

      describe 'Filtering with Organization Guid' do
        context 'When Organization Guid Not Present' do
          it 'Return Resource length zero' do
            get 'v2/routes?q=organization_guid:notpresent', {}, admin_headers
            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(0)
          end
        end

        context 'When Organization Guid Present' do
          let(:first_route_info) { decoded_response.fetch('resources').first }
          let(:second_route_info) { decoded_response.fetch('resources').last }
          let(:space1) { Space.make(organization: organization) }
          let(:route1) { Route.make(domain: domain, space: space1) }

          it 'Allows filtering by organization_guid' do
            org_guid = organization.guid
            route_guid = route.guid

            get "v2/routes?q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows organization_guid query at any place in query ' do
            org_guid = organization.guid
            route_guid = route.guid
            domain_guid = domain.guid

            get "v2/routes?q=domain_guid:#{domain_guid}&q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows organization_guid query at any place in query with all querables' do
            org_guid = organization.guid
            taken_host = 'someroute'
            route_temp = Route.make(host: taken_host, domain: domain, space: space)
            route_guid = route_temp.guid
            domain_guid = domain.guid

            get "v2/routes?q=host:#{taken_host}&q=organization_guid:#{org_guid}&q=domain_guid:#{domain_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows filtering at organization level' do
            org_guid = organization.guid
            route_guid = route.guid
            route1_guid = route1.guid

            get "v2/routes?q=organization_guid:#{org_guid}", {}, admin_headers

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(2)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
            expect(second_route_info.fetch('metadata').fetch('guid')).to eq(route1_guid)
          end
        end
      end
    end

    describe 'GET /v2/routes/reserved/domain/:domain_guid/host/:hostname' do
      let(:user) { User.make }

      context 'when the domain does not exist' do
        it 'returns a NOT_FOUND (404)' do
          get '/v2/routes/reserved/domain/nothere/host/myhost', nil, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the domain exists' do
        let(:route) { Route.make }

        context 'when the hostname is not reserved' do
          it 'returns a NOT_FOUND (404)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/myhost", nil, headers_for(user)
            expect(last_response.status).to eq(404)
          end
        end

        context 'when the hostname is reserved' do
          it 'returns a NO_CONTENT (204)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}", nil, headers_for(user)
            expect(last_response.status).to eq(204)
          end
        end

        context 'when a path is provided as a param' do
          context 'when the path does not exist' do
            it 'returns a NOT_FOUND (404)' do
              get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=not_mypath", nil, headers_for(user)
              expect(last_response.status).to eq(404)
            end
          end

          context ' when the path does exist' do
            context 'when the path does not contain url encoding' do
              let(:path) { '/my_path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT (204)' do
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{path}", nil, headers_for(user)
                expect(last_response.status).to eq(204)
              end
            end

            context 'when the path is url encoded' do
              let(:path) { '/my%20path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT' do
                uri_encoded_path = '%2Fmy%2520path'
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{uri_encoded_path}", nil, headers_for(user)
                expect(last_response.status).to eq(204)
              end
            end
          end
        end
      end
    end
  end
end
