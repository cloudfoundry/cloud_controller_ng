require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RoutesController do
    let(:routing_api_client) { double('routing_api_client', enabled?: true) }
    let(:tcp_group_1) { 'tcp-group-1' }
    let(:tcp_group_2) { 'tcp-group-2' }
    let(:tcp_group_3) { 'tcp-group-3' }
    let(:http_group) { 'http-group' }
    let(:user) { User.make }
    let(:router_groups) do
      [
        RoutingApi::RouterGroup.new({ 'guid' => tcp_group_1, 'name' => 'TCP1', 'type' => 'tcp', 'reservable_ports' => '1024-65535' }),
        RoutingApi::RouterGroup.new({ 'guid' => tcp_group_2, 'name' => 'TCP2', 'type' => 'tcp', 'reservable_ports' => '1024-65535' }),
        RoutingApi::RouterGroup.new({ 'guid' => tcp_group_3, 'name' => 'TCP3', 'type' => 'tcp', 'reservable_ports' => '50000-50001' }),
        RoutingApi::RouterGroup.new({ 'guid' => http_group, 'type' => 'http' }),
      ]
    end
    let(:app_event_repository) { instance_double(Repositories::AppEventRepository) }
    let(:route_event_repository) { instance_double(Repositories::RouteEventRepository).as_null_object }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(routing_api_client)
      allow(CloudController::DependencyLocator.instance).to receive(:app_event_repository).and_return(app_event_repository)
      allow(CloudController::DependencyLocator.instance).to receive(:route_event_repository).and_return(route_event_repository)
      allow(routing_api_client).to receive(:router_group).with(tcp_group_1).and_return(router_groups[0])
      allow(routing_api_client).to receive(:router_group).with(tcp_group_2).and_return(router_groups[1])
      allow(routing_api_client).to receive(:router_group).with(tcp_group_3).and_return(router_groups[2])
      allow(routing_api_client).to receive(:router_group).with(http_group).and_return(router_groups[3])
    end

    describe 'Query Parameters' do
      it { expect(VCAP::CloudController::RoutesController).to be_queryable_by(:host) }
      it { expect(VCAP::CloudController::RoutesController).to be_queryable_by(:domain_guid) }
      it { expect(VCAP::CloudController::RoutesController).to be_queryable_by(:organization_guid) }
      it { expect(VCAP::CloudController::RoutesController).to be_queryable_by(:path) }
      it { expect(VCAP::CloudController::RoutesController).to be_queryable_by(:port) }
    end

    describe 'Attributes' do
      it do
        expect(VCAP::CloudController::RoutesController).to have_creatable_attributes(
          host:        { type: 'string', default: '' },
          domain_guid: { type: 'string', required: true },
          space_guid:  { type: 'string', required: true },
          path:        { type: 'string' },
          port:        { type: 'integer' }
        )
      end
      it do
        expect(VCAP::CloudController::RoutesController).to have_updatable_attributes(
          host:        { type: 'string' },
          domain_guid: { type: 'string' },
          space_guid:  { type: 'string' },
          path:        { type: 'string' },
          port:        { type: 'integer' }
        )
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
              name:      'route',
              path:      '/v2/routes',
              enumerate: 1
          end

          describe 'OrgUser' do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples 'permission enumeration', 'OrgUser',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 0
          end

          describe 'BillingManager' do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples 'permission enumeration', 'BillingManager',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 0
          end

          describe 'Auditor' do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples 'permission enumeration', 'Auditor',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 1
          end
        end

        describe 'App Space Level Permissions' do
          describe 'SpaceManager' do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples 'permission enumeration', 'SpaceManager',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 1
          end

          describe 'Developer' do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples 'permission enumeration', 'Developer',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 1
          end

          describe 'SpaceAuditor' do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples 'permission enumeration', 'SpaceAuditor',
              name:      'route',
              path:      '/v2/routes',
              enumerate: 1
          end
        end
      end
    end

    describe 'Associations' do
      it do
        expect(VCAP::CloudController::RoutesController).to have_nested_routes({ apps: [:get], route_mappings: [:get] })
      end

      context 'with Docker app' do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let(:organization) { Organization.make }
        let(:http_domain) { PrivateDomain.make(owning_organization: organization) }
        let(:space) { Space.make(organization: organization) }
        let(:route) { Route.make(domain: http_domain, space: space) }
        let!(:docker_process) do
          ProcessModelFactory.make(space: space, docker_image: 'some-image', state: 'STARTED')
        end

        context 'and Docker disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
            set_current_user_as_admin
          end

          it 'associates the route with the app' do
            put "/v2/routes/#{route.guid}/apps/#{docker_process.guid}", MultiJson.dump(guid: route.guid)

            expect(last_response.status).to eq(201)
          end
        end
      end
    end

    describe 'DELETE /v2/routes/:guid' do
      let(:route) { Route.make }

      before do
        allow(app_event_repository).to receive(:record_unmap_route)
        developer = make_developer_for_space(route.space)
        set_current_user(developer)
      end

      it 'deletes the route' do
        delete "v2/routes/#{route.guid}"

        expect(last_response.status).to eq 204
        expect(route.exists?).to be_falsey
      end

      context 'when async=true' do
        it 'deletes the route in a background job' do
          delete "v2/routes/#{route.guid}?async=true"

          expect(last_response.status).to eq 202
          expect(route.exists?).to be_truthy

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(route.exists?).to be_falsey
        end
      end

      context 'when recursive=true' do
        let(:route_delete) { instance_double(RouteDelete) }

        before do
          allow(RouteDelete).to receive(:new).and_return(route_delete)
        end

        it 'passes recursive true to async deletes' do
          allow(route_delete).to receive(:delete_async)
          delete "v2/routes/#{route.guid}?recursive=true&async=true"
          expect(route_delete).to have_received(:delete_async).with(route: route, recursive: true)
        end

        it 'passes recursive true to sync deletes' do
          allow(route_delete).to receive(:delete_sync)
          delete "v2/routes/#{route.guid}?recursive=true&async=false"
          expect(route_delete).to have_received(:delete_sync).with(route: route, recursive: true)
        end
      end

      context 'when a ServiceInstanceAssociationError is raised' do
        before do
          route_delete = instance_double(RouteDelete)
          allow(route_delete).to receive(:delete_sync).
            with(route: route, recursive: false).
            and_raise(RouteDelete::ServiceInstanceAssociationError.new)
          allow(RouteDelete).to receive(:new).and_return(route_delete)
        end

        it 'raises an error and does not delete anything' do
          delete "v2/routes/#{route.guid}"

          expect(last_response).to have_status_code 400
          expect(last_response.body).to include 'AssociationNotEmpty'
          expect(last_response.body).to include
          'Please delete the service_instance associations for your routes'
        end
      end
    end

    describe 'POST /v2/routes' do
      let(:space_quota_definition) { SpaceQuotaDefinition.make }
      let(:space) do
        Space.make(space_quota_definition: space_quota_definition,
                   organization: space_quota_definition.organization)
      end
      let(:shared_domain) { SharedDomain.make }
      let(:domain_guid) { shared_domain.guid }
      let(:host) { 'example' }
      let(:port) { nil }
      let(:path) { '' }
      let(:req) do
        {
          domain_guid: domain_guid,
          space_guid:  space.guid,
          host:        host,
          port:        port,
          path:        path
        }
      end

      before do
        set_current_user(user)
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'creates a route' do
        post '/v2/routes', MultiJson.dump(req)

        created_route = Route.last
        expect(last_response).to have_status_code(201)
        expect(last_response.headers).to include('Location')
        expect(last_response.headers['Location']).to eq("#{RoutesController.path}/#{created_route.guid}")
        expect(last_response.body).to include(created_route.guid)
        expect(last_response.body).to include(created_route.host)
        expect(created_route.host).to eq('example')
      end

      context 'when copilot is enabled' do
        before do
          TestConfig.override(copilot: { enabled: true })
          allow(CopilotHandler).to receive(:create_route)
        end

        it 'creates a route and notifies Copilot' do
          post '/v2/routes', MultiJson.dump(req)

          created_route = Route.last
          expect(last_response).to have_status_code(201)
          expect(last_response.headers).to include('Location')
          expect(last_response.headers['Location']).to eq("#{RoutesController.path}/#{created_route.guid}")
          expect(last_response.body).to include(created_route.guid)
          expect(last_response.body).to include(created_route.host)
          expect(created_route.host).to eq('example')
          expect(CopilotHandler).to have_received(:create_route)
        end

        context 'when the call to copilot fails' do
          let(:logger) { instance_double(Steno::Logger) }

          before do
            allow(CopilotHandler).to receive(:create_route).and_raise(CopilotHandler::CopilotUnavailable.new('something'))
            allow_any_instance_of(RoutesController).to receive(:logger).and_return(logger)
            allow(logger).to receive(:debug)
          end

          it 'logs that we could not communicate with copilot' do
            expect(logger).to receive(:error).with('failed communicating with copilot backend: something')

            post '/v2/routes', MultiJson.dump(req)

            created_route = Route.last
            expect(last_response).to have_status_code(201)
            expect(last_response.headers).to include('Location')
            expect(last_response.headers['Location']).to eq("#{RoutesController.path}/#{created_route.guid}")
            expect(last_response.body).to include(created_route.guid)
            expect(last_response.body).to include(created_route.host)
            expect(created_route.host).to eq('example')
            expect(CopilotHandler).to have_received(:create_route)
          end
        end
      end

      context 'when the requested route specifies a system hostname and a system domain' do
        let(:space) { Space.make(organization: system_domain.owning_organization) }
        let(:system_domain) { Domain.find(name: TestConfig.config[:system_domain]) }
        let(:host) { 'api' }
        let(:req) do
          { domain_guid: system_domain.guid,
            space_guid:  space.guid,
            host:        host,
            port:        nil,
            path:        '/foo' }
        end

        before { TestConfig.override(system_hostnames: [host]) }

        it 'returns a 400 RouteHostTaken' do
          post '/v2/routes', MultiJson.dump(req)

          expect(last_response).to have_status_code(400)
          expect(decoded_response['code']).to eq(210003)
          expect(decoded_response['error_code']).to eq('CF-RouteHostTaken')
          expect(decoded_response['description']).to eq('The host is taken: api is a system domain')
        end
      end

      context 'when the domain does not exist' do
        let(:domain_guid) { 'not-exist' }

        it 'returns a 400' do
          post '/v2/routes?generate_port=true', MultiJson.dump(req)

          expect(last_response).to have_status_code(400)
          expect(decoded_response['description']).to eq('The domain is invalid: Domain with guid not-exist does not exist')
        end
      end

      context 'when a port is specified for an http domain' do
        let(:port) { 1050 }

        it 'returns a 400 RouteInvalid' do
          post '/v2/routes', MultiJson.dump(req)

          expect(last_response).to have_status_code(400)
          expect(decoded_response['error_code']).to eq 'CF-RouteInvalid'
          expect(decoded_response['description']).to include('Port is supported for domains of TCP router groups only')
        end
      end

      context 'when the route contains invalid characters' do
        it 'returns 400 RouteInvalid' do
          post '/v2/routes', MultiJson.dump(host: 'myexample!*', domain_guid: domain_guid, space_guid: space.guid)

          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to eq(210001)
        end
      end

      context 'when host is already taken and no paths are requested' do
        it 'returns 400 RouteHostTaken' do
          taken_host = 'someroute'
          Route.make(host: taken_host, domain: shared_domain)

          post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain_guid, space_guid: space.guid)

          expect(last_response).to have_status_code(400)
          expect(decoded_response['code']).to eq(210003)
        end
      end

      describe 'paths' do
        context 'when the specified path contains only "/"' do
          it 'returns 400 PathInvalid' do
            post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: shared_domain.guid, space_guid: space.guid, path: '/')

            expect(last_response.status).to eq(400)
            expect(decoded_response['error_code']).to eq('CF-PathInvalid')
            expect(decoded_response['description']).to eq('The path is invalid: the path cannot be a single slash')
          end
        end

        context 'when the specified path does not start with "/"' do
          it 'returns 400 PathInvalid' do
            post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: shared_domain.guid, space_guid: space.guid, path: 'a/')

            expect(last_response.status).to eq(400)
            expect(decoded_response['error_code']).to eq('CF-PathInvalid')
            expect(decoded_response['description']).to eq('The path is invalid: the path must start with a "/"')
          end
        end

        context 'when the specified path contains a question mark' do
          it 'returns 400 PathInvalid' do
            post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: shared_domain.guid, space_guid: space.guid, path: '/v2/zak?')

            expect(last_response.status).to eq(400)
            expect(decoded_response['error_code']).to eq('CF-PathInvalid')
            expect(decoded_response['description']).to include('The path is invalid: illegal "?" character')
          end
        end

        context 'when the path is already in use by the same host' do
          it 'returns the RoutePathTaken message when paths conflict' do
            taken_host = 'someroute'
            path       = '/%2Fsome%20path'
            post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain_guid, space_guid: space.guid, path: path)
            expect(last_response.status).to eq(201)

            post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: domain_guid, space_guid: space.guid, path: path)

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(210004)
          end
        end
      end

      context 'shared domains' do
        let(:shared_domain) { SharedDomain.make }
        let(:another_space) { Space.make }
        let(:req) do
          {
            domain_guid: shared_domain.guid,
            space_guid:  another_space.guid,
            host:        host,
            port:        nil,
            path:        '/foo'
          }
        end

        context 'when the route already exists with the same host in a another space' do
          before do
            Route.make(domain: shared_domain, host: host, space: space)
            another_space.organization.add_user(user)
            another_space.add_developer(user)
          end

          it 'fails with an RouteInvalid' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
            expect(decoded_response['description']).
              to include('Routes for this host and domain have been reserved for another space')
          end
        end

        context 'when the specified route is too long' do
          let(:host) { 'f' * 64 }
          let(:req) do
            {
              domain_guid: shared_domain.guid,
              space_guid:  space.guid,
              host:        host,
            }
          end

          it 'fails with an RouteInvalid' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
            expect(decoded_response['description']).
              to include('host must be no more than')
          end
        end
      end

      context 'private domains' do
        let(:private_domain) { PrivateDomain.make(owning_organization_guid: space.organization.guid) }
        let(:routing_api_client) { double('routing_api_client', enabled?: true) }
        let(:router_group) {
          RoutingApi::RouterGroup.new({
            'guid'             => 'tcp-guid',
            'type'             => 'tcp',
            'reservable_ports' => '1024-65535'
          })
        }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
            and_return(routing_api_client)
          allow(routing_api_client).to receive(:router_group).and_return(router_group)
        end

        context 'when a port is part of the request' do
          it 'returns RouteInvalid when port is provided' do
            post '/v2/routes', MultiJson.dump(port: 8080,
                                              domain_guid: private_domain.guid,
                                              space_guid: space.guid)

            expect(last_response.status).to eq(400)
            expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
            expect(decoded_response['description']).to eq('The route is invalid: Port is supported for domains of TCP router groups only.')
          end
        end
      end

      context 'internal domains' do
        let(:internal_domain) { Domain.make(internal: true, wildcard: true) }

        context 'and path is present' do
          it 'returns RouteInvalid' do
            post '/v2/routes', MultiJson.dump(domain_guid: internal_domain.guid, space_guid: space.guid, path: '/v2/zak', host: 'my-host')

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Path is not supported for internal domains.')
          end
        end

        context 'host is wildcard' do
          before do
            set_current_user_as_admin(user: user)
          end

          it 'returns RouteInvalid' do
            post '/v2/routes', MultiJson.dump(domain_guid: internal_domain.guid, space_guid: space.guid, host: '*')

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include('Wild card host names are not supported for internal domains.')
          end
        end
      end

      context 'tcp domains' do
        let(:tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
        let(:another_tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }

        context 'when the requested port is already in use by another domain with the same router group' do
          it 'returns the RoutePortTaken message when ports conflict' do
            taken_port = 1024
            post '/v2/routes', MultiJson.dump(host: '',
                                              domain_guid: tcp_domain.guid,
                                              space_guid:  space.guid,
                                              port: taken_port)

            post '/v2/routes', MultiJson.dump(host: '',
                                              domain_guid: another_tcp_domain.guid,
                                              space_guid:  space.guid,
                                              port: taken_port)

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(210005)
            expect(decoded_response['error_code']).to eq('CF-RoutePortTaken')
          end
        end

        context 'when uaa is unavailable to the routing api client' do
          before do
            allow_any_instance_of(RouteValidator).to receive(:validate).and_raise(RoutingApi::UaaUnavailable)
          end

          it 'returns a 503 UaaUnavailable' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(503)
            expect(decoded_response['error_code']).to eq('CF-UaaUnavailable')
            expect(decoded_response['description']).to eq('The UAA service is currently unavailable')
          end
        end

        context 'when the routing api is disabled' do
          before do
            allow_any_instance_of(RouteValidator).to receive(:validate).and_raise(RoutingApi::RoutingApiDisabled)
          end

          it 'returns a 403' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(403)
            expect(decoded_response['error_code']).to eq('CF-RoutingApiDisabled')
            expect(decoded_response['description']).to eq('Routing API is disabled')
          end
        end

        context 'when the routing api is unavailable' do
          before do
            allow_any_instance_of(RouteValidator).to receive(:validate).and_raise(RoutingApi::RoutingApiUnavailable)
          end

          it 'returns a 503' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(503)
            expect(decoded_response['error_code']).to eq('CF-RoutingApiUnavailable')
            expect(decoded_response['description']).to eq('The Routing API is currently unavailable')
          end
        end

        context 'when the routing api has experienced data loss' do
          let(:orphaned_shared_domain) { SharedDomain.make(router_group_guid: 'abc') }
          let(:req) { {
            domain_guid: orphaned_shared_domain.guid,
            space_guid:  space.guid,
            port:        1234,
          } }

          before do
            allow(routing_api_client).to receive(:router_group).and_return(nil)
          end

          it 'returns a 404' do
            post '/v2/routes', MultiJson.dump(req)

            expect(last_response).to have_status_code(404)
            expect(decoded_response['error_code']).to eq('CF-RouterGroupNotFound')
            expect(decoded_response['description']).to eq('The router group could not be found: abc')
          end
        end

        context 'generate_port' do
          let(:generated_port) { 10005 }
          let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
          let(:domain_guid) { domain.guid }
          let(:port) { nil }

          before do
            allow_any_instance_of(RouteValidator).to receive(:validate)
            allow_any_instance_of(PortGenerator).to receive(:generate_port).and_return(generated_port)
          end

          context 'when requesting a randomly generated port' do
            context 'and no port is specified' do
              it 'successfully generates a port without warning' do
                post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                expect(last_response.status).to eq(201)
                expect(last_response.body).to include("\"port\": #{generated_port}")
                expect(last_response.headers).not_to include('X-CF-Warnings')
              end
            end

            context 'and a port is specified' do
              let(:port) { 10500 }
              let(:generated_port) { 14098 }
              let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
              let(:domain_guid) { domain.guid }
              let(:port_override_warning) { 'Specified+port+ignored.+Random+port+generated.' }

              it 'creates a route with a generated random port with a warning' do
                post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                expect(last_response.status).to eq(201)
                expect(last_response.body).to include("\"port\": #{generated_port}")
                expect(last_response.headers).to include('X-CF-Warnings')
                expect(last_response.headers['X-CF-Warnings']).to include(port_override_warning)
              end
            end
          end

          context 'when generate_port is not boolean' do
            it 'returns a 400' do
              post '/v2/routes?generate_port=lol', MultiJson.dump(req), headers_for(user)

              expect(last_response.status).to eq(400)
            end
          end

          context 'when the routing api is disabled' do
            before do
              allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                and_return(RoutingApi::DisabledClient.new)
            end

            it 'returns a 403' do
              post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(403)
              expect(decoded_response['error_code']).to eq('CF-RoutingApiDisabled')
              expect(decoded_response['description']).to eq('Routing API is disabled')
            end
          end

          context 'when the router group runs out of ports' do
            let(:generated_port) { -1 }
            let(:domain) { SharedDomain.make(router_group_guid: tcp_group_3) }
            let(:domain_guid) { domain.guid }

            before do
              allow_any_instance_of(PortGenerator).to receive(:generate_port).and_return(generated_port)
            end

            it 'returns 403' do
              post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

              expect(last_response.status).to eq(403)
              expect(decoded_response['error_code']).to eq('CF-OutOfRouterGroupPorts')
              expect(decoded_response['description']).to eq('There are no more ports available for router group: TCP3. Please contact your administrator for more information.')
            end
          end

          context 'when queried with a shared http domain' do
            let(:shared_http_domain) { SharedDomain.make(router_group_guid: http_group) }

            it 'returns 400 RouteInvalid' do
              post '/v2/routes?generate_port=true', MultiJson.dump(domain_guid: shared_http_domain.guid, space_guid: space.guid)

              expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
              expect(last_response.status).to eq(400)
              expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
              expect(last_response.body).to include('Port is supported for domains of TCP router groups only.')
            end
          end

          context 'when queried with a private http domain' do
            let(:private_domain) { PrivateDomain.make(owning_organization_guid: space.organization.guid) }
            let(:routing_api_client) { double('routing_api_client', enabled?: true) }
            let(:router_group) {
              RoutingApi::RouterGroup.new({
                'guid'             => 'tcp-guid',
                'type'             => 'tcp',
                'reservable_ports' => '1024-65535'
              })
            }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
                and_return(routing_api_client)
              allow(routing_api_client).to receive(:router_group).and_return(router_group)
            end

            it 'returns RouteInvalid' do
              post '/v2/routes?generate_port=true', MultiJson.dump(domain_guid: private_domain.guid, space_guid: space.guid)

              expect(last_response.status).to eq(400)
              expect(decoded_response['error_code']).to eq('CF-RouteInvalid')
              expect(decoded_response['description']).to eq('The route is invalid: Port is supported for domains of TCP router groups only.')
            end
          end

          context 'when not requesting a randomly generated port' do
            context 'when a port is specified' do
              let(:port) { 10500 }

              it 'creates a route with the requested port' do
                post '/v2/routes?generate_port=false', MultiJson.dump(req), headers_for(user)

                expect(last_response.status).to eq(201)
                expect(last_response.body).to include("\"port\": #{port}")
              end
            end
          end
        end
      end

      context 'quotas' do
        context 'when the total routes quota for the space has maxed out' do
          it 'returns 400 SpaceQuotaTotalRoutesExceeded' do
            quota_definition             = SpaceQuotaDefinition.make(total_routes: 0, organization: space.organization)
            space.space_quota_definition = quota_definition
            space.save

            post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: shared_domain.guid, space_guid: space.guid)

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(310005)
            expect(decoded_response['error_code']).to eq('CF-SpaceQuotaTotalRoutesExceeded')
          end
        end

        context 'when the total routes quota for the org has maxed out' do
          it 'returns 400 OrgQuotaTotalRoutesExceeded' do
            quota_definition                            = space.organization.quota_definition
            quota_definition.total_reserved_route_ports = 0
            quota_definition.total_routes               = 0
            quota_definition.save

            post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: shared_domain.guid, space_guid: space.guid)

            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(310006)
          end
        end

        context 'when the total reserved route ports quota for the org has maxed out' do
          let(:tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }

          it 'returns 400 OrgQuotaTotalReservedRoutePortsExceeded' do
            quota_definition                            = space.organization.quota_definition
            quota_definition.total_reserved_route_ports = 0
            quota_definition.save

            post '/v2/routes', MultiJson.dump(domain_guid: tcp_domain.guid, space_guid: space.guid, port: 1234)

            expect(last_response.status).to eq(400)
            expect(last_response.body).to include 'You have exceeded the total reserved route ports for your organization\'s quota.'
            expect(decoded_response['code']).to eq(310009)
          end
        end

        context 'when the total reserved route ports quota for the space has maxed out' do
          let(:tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }

          it 'returns 400 SpaceQuotaTotalReservedRoutePortsExceeded' do
            quota_definition             = SpaceQuotaDefinition.make(total_reserved_route_ports: 0, organization: space.organization)
            space.space_quota_definition = quota_definition
            space.save

            post '/v2/routes', MultiJson.dump(domain_guid: tcp_domain.guid, space_guid: space.guid, port: 1234)

            expect(last_response).to have_status_code(400)
            expect(last_response.body).to include 'You have exceeded the total reserved route ports for your space\'s quota.'
            expect(decoded_response['code']).to eq(310010)
          end
        end
      end

      context 'when route_creation feature flag is disabled' do
        before do
          allow_any_instance_of(RouteValidator).to receive(:validate)
          FeatureFlag.make(name: 'route_creation', enabled: false, error_message: nil)
        end

        it 'returns FeatureDisabled for users' do
          post '/v2/routes', MultiJson.dump(req)

          expect(last_response.status).to eq(403)
          expect(decoded_response['error_code']).to eq('CF-FeatureDisabled')
          expect(decoded_response['description']).to eq('Feature Disabled: route_creation')
        end
      end
    end

    describe 'PUT /v2/routes/:guid' do
      let(:space_quota_definition) { SpaceQuotaDefinition.make }
      let(:space) { Space.make(space_quota_definition: space_quota_definition,
                               organization:                                  space_quota_definition.organization)
      }
      let(:user) { User.make }
      let(:domain) { SharedDomain.make }
      let(:domain_guid) { domain.guid }

      before do
        space.organization.add_user(user)
        space.add_developer(user)
        set_current_user(user)
      end

      describe 'tcp routes' do
        let(:port) { 18000 }
        let(:new_port) { 514 }
        let(:tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
        let(:route) { Route.make(space: space, domain: tcp_domain, port: port, host: '') }
        let(:req) { {
          port: new_port,
        } }

        context 'when port is not in reservable port range' do
          it 'returns an error' do
            put "/v2/routes/#{route.guid}", MultiJson.dump(req)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('The requested port is not available for reservation.')
            expect(decoded_response['error_code']).to eq 'CF-RouteInvalid'
          end
        end

        context 'when updating a route with a new port value that is not null' do
          let(:new_port) { 20000 }
          let(:req) { {
            port: new_port,
          } }

          context 'with a domain with a router_group_guid and type tcp' do
            let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }

            it 'updates the route' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req)

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['port']).to eq(new_port)
            end

            context 'with the current port' do
              let(:new_port) { port }

              it 'updates the route' do
                put "/v2/routes/#{route.guid}", MultiJson.dump(req)

                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['port']).to eq(new_port)
              end
            end
          end

          context 'when the routing api client raises a UaaUnavailable error' do
            let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
            let!(:route) { Route.make(space: space, domain: tcp_domain, port: port, host: '') }
            before do
              allow_any_instance_of(RouteValidator).to receive(:validate).
                and_raise(RoutingApi::UaaUnavailable)
            end

            it 'returns a 503 Service Unavailable' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req)

              expect(last_response).to have_status_code(503)
              expect(last_response.body).to include 'The UAA service is currently unavailable'
            end
          end

          context 'when the routing api client raises a RoutingApiUnavailable error' do
            let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
            let!(:route) { Route.make(space: space, domain: tcp_domain, port: port, host: '') }
            before do
              allow_any_instance_of(RouteValidator).to receive(:validate).
                and_raise(RoutingApi::RoutingApiUnavailable)
            end

            it 'returns a 503 Service Unavailable' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req)

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
          set_current_user(user)

          get "/v2/routes/#{route.guid}"

          expect(last_response.status).to eq 200
          expect(decoded_response['entity']['domain_guid']).to_not be_nil
        end
      end

      context 'as an admin' do
        it 'includes the domain guid' do
          set_current_user_as_admin

          get "/v2/routes/#{route.guid}"

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

      before { set_current_user_as_admin }

      it 'should contain links to the route_mappings resource' do
        route_guid = route.guid
        get 'v2/routes'
        expect(last_response.status).to eq(200), last_response.body

        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['entity']['route_mappings_url']).
          to eq("/v2/routes/#{route_guid}/route_mappings")
      end

      describe 'Filtering with Organization Guid' do
        context 'When Organization Guid Not Present' do
          it 'Return Resource length zero' do
            get 'v2/routes?q=organization_guid:notpresent'
            expect(last_response.status).to eq(200), last_response.body
            expect(decoded_response['resources'].length).to eq(0)
          end
        end

        context 'When Organization Guid Present' do
          let(:first_route_info) { decoded_response.fetch('resources')[0] }
          let(:second_route_info) { decoded_response.fetch('resources')[1] }
          let(:third_route_info) { decoded_response.fetch('resources')[2] }
          let(:space1) { Space.make(organization: organization) }
          let(:route1) { Route.make(domain: domain, space: space1) }

          let(:organization2) { Organization.make }
          let(:domain2) { PrivateDomain.make(owning_organization: organization2) }
          let(:space2) { Space.make(organization: organization2) }
          let(:route2) { Route.make(domain: domain2, space: space2) }

          context 'when the details fit on the first page' do
            it 'Allows filtering by organization_guid' do
              org_guid   = organization.guid
              route_guid = route.guid

              get "v2/routes?q=organization_guid:#{org_guid}"

              expect(last_response.status).to eq(200)
              expect(decoded_response['resources'].length).to eq(1)
              expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
            end
          end

          context 'with pagination' do
            let(:results_per_page) { 1 }
            let(:route2) { Route.make(domain: domain1, space: space1) }
            let(:route3) { Route.make(domain: domain2, space: space2) }
            let!(:instances) do
              [route1, route2, route3]
            end
            let(:domain1) { domain }
            let(:org1) { organization }
            let(:org2) { organization2 }

            context 'at page 1' do
              let(:page) { 1 }
              it 'passes the org_guid filter into the next_url' do
                get "v2/routes?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
                expect(last_response.status).to eq(200), last_response.body
                routes = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(routes.length).to eq(1)
                expect(routes).to include(instances[0].guid)
                result = JSON.parse(last_response.body)
                expect(result['next_url']).to include("q=organization_guid:#{org1.guid}"), result['next_url']
                expect(result['prev_url']).to be_nil
              end
            end

            context 'at page 2' do
              let(:page) { 2 }
              it 'passes the org_guid filter into the next_url' do
                get "v2/routes?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
                expect(last_response.status).to eq(200), last_response.body
                routes = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(routes.length).to eq(1)
                expect(routes).to include(instances[1].guid)
                result = JSON.parse(last_response.body)
                expect(result['next_url']).to be_nil
                expect(result['prev_url']).to include("q=organization_guid:#{org1.guid}"), result['prev_url']
              end
            end

            context 'at page 3' do
              let(:page) { 3 }
              it 'passes the org_guid filter into the next_url' do
                get "v2/routes?page=#{page}&results-per-page=#{results_per_page}&q=organization_guid:#{org1.guid}"
                expect(last_response.status).to eq(200), last_response.body
                routes = decoded_response['resources'].map { |resource| resource.fetch('metadata').fetch('guid') }
                expect(routes.length).to eq(0)
                result = JSON.parse(last_response.body)
                expect(result['next_url']).to be_nil
                expect(result['prev_url']).to include("q=organization_guid:#{org1.guid}"), result['prev_url']
              end
            end
          end

          it 'Allows organization_guid query at any place in query ' do
            org_guid    = organization.guid
            route_guid  = route.guid
            domain_guid = domain.guid

            get "v2/routes?q=domain_guid:#{domain_guid}&q=organization_guid:#{org_guid}"

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows organization_guid query at any place in query with all querables' do
            org_guid    = organization.guid
            taken_host  = 'someroute'
            route_temp  = Route.make(host: taken_host, domain: domain, space: space)
            route_guid  = route_temp.guid
            domain_guid = domain.guid

            get "v2/routes?q=host:#{taken_host}&q=organization_guid:#{org_guid}&q=domain_guid:#{domain_guid}"

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(1)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
          end

          it 'Allows filtering at organization level' do
            org_guid    = organization.guid
            route_guid  = route.guid
            route1_guid = route1.guid

            get "v2/routes?q=organization_guid:#{org_guid}"

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(2)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
            expect(second_route_info.fetch('metadata').fetch('guid')).to eq(route1_guid)
          end

          it 'Allows filtering at organization level with multiple guids' do
            org_guid    = organization.guid
            route_guid  = route.guid
            route1_guid = route1.guid

            org2_guid   = organization2.guid
            route2_guid = route2.guid

            get "v2/routes?q=organization_guid%20IN%20#{org_guid},#{org2_guid}"

            expect(last_response.status).to eq(200)
            expect(decoded_response['resources'].length).to eq(3)
            expect(first_route_info.fetch('metadata').fetch('guid')).to eq(route_guid)
            expect(second_route_info.fetch('metadata').fetch('guid')).to eq(route1_guid)
            expect(third_route_info.fetch('metadata').fetch('guid')).to eq(route2_guid)
          end
        end
      end
    end

    describe 'GET /v2/routes/:guid/route_mappings' do
      let(:organization) { Organization.make }
      let(:domain) { PrivateDomain.make(owning_organization: organization) }
      let(:space) { Space.make(organization: organization) }
      let(:route) { Route.make(domain: domain, space: space) }
      let(:process) { ProcessModelFactory.make(space: route.space) }
      let!(:app_route_mapping) { RouteMappingModel.make(route: route, app: process.app, process_type: process.type) }

      before { set_current_user_as_admin }

      it 'lists the route mappings' do
        get "v2/routes/#{route.guid}/route_mappings"
        expect(last_response).to have_status_code(200)
        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['metadata']['guid']).to eq app_route_mapping.guid
      end

      context 'when user has no access to the route' do
        it 'returns forbidden error' do
          set_current_user(User.make)

          get "v2/routes/#{route.guid}/route_mappings"
          expect(last_response).to have_status_code(403)
        end
      end

      context 'when a route has no route_mappings' do
        let(:route_2) { Route.make(domain: domain, space: space) }

        it 'returns an empty collection' do
          get "v2/routes/#{route_2.guid}/route_mappings"
          expect(last_response).to have_status_code(200)
          expect(decoded_response['resources'].length).to eq(0)
        end
      end

      context 'when an non existing route is specified' do
        it 'returns resource not found' do
          get 'v2/routes/non-existing-route-guid/route_mappings'
          expect(last_response).to have_status_code(404)
        end
      end
    end

    describe 'GET /v2/routes/reserved/domain/:domain_guid/host/:hostname' do
      before { set_current_user(User.make) }

      context 'when the domain does not exist' do
        it 'returns a NOT_FOUND (404)' do
          get '/v2/routes/reserved/domain/nothere/host/myhost'
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the domain exists' do
        let(:route) { Route.make }

        context 'when the hostname is not reserved' do
          it 'returns a NOT_FOUND (404)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/myhost"
            expect(last_response.status).to eq(404)
          end
        end

        context 'when the hostname is reserved' do
          it 'returns a NO_CONTENT (204)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}"
            expect(last_response.status).to eq(204)
          end
        end

        context 'when a path is provided as a param' do
          context 'when the path does not exist' do
            it 'returns a NOT_FOUND (404)' do
              get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=not_mypath"
              expect(last_response.status).to eq(404)
            end
          end

          context ' when the path does exist' do
            context 'when the path does not contain url encoding' do
              let(:path) { '/my_path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT (204)' do
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{path}"
                expect(last_response.status).to eq(204)
              end
            end

            context 'when the path is url encoded' do
              let(:path) { '/my%20path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT' do
                uri_encoded_path = '%2Fmy%2520path'
                get "/v2/routes/reserved/domain/#{route.domain_guid}/host/#{route.host}?path=#{uri_encoded_path}"
                expect(last_response.status).to eq(204)
              end
            end
          end
        end
      end
    end

    describe 'GET /v2/routes/reserved/domain/:domain_guid' do
      before { set_current_user(User.make) }

      context 'when the domain does not exist' do
        it 'returns a NOT_FOUND (404)' do
          get '/v2/routes/reserved/domain/nothere'
          expect(last_response).to have_status_code(404)
        end
      end

      context 'when the domain exists' do
        let(:route) { Route.make }

        it 'returns a NOT_FOUND (404)' do
          get "/v2/routes/reserved/domain/#{route.domain_guid}"
          expect(last_response).to have_status_code(404)
        end

        context 'when the domain is a private domain' do
          let(:domain) { PrivateDomain.make }
          let(:route) { Route.make(domain: domain, host: '', space: Space.make(organization: domain.owning_organization)) }

          it 'returns NO_CONTENT (204)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}"
            expect(last_response).to have_status_code(204)
          end
        end

        context 'when the hostname is not reserved' do
          it 'returns a NOT_FOUND (404)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}?host=myhost"
            expect(last_response).to have_status_code(404)
          end
        end

        context 'when the hostname is reserved' do
          it 'returns a NO_CONTENT (204)' do
            get "/v2/routes/reserved/domain/#{route.domain_guid}?host=#{route.host}"
            expect(last_response).to have_status_code(204)
          end
        end

        context 'when the route is tcp route' do
          let(:tcp_domain) { SharedDomain.make(router_group_guid: 'tcp-group-1') }
          let(:tcp_2_domain) { SharedDomain.make(router_group_guid: 'tcp-group-1') }
          let(:tcp_route) { Route.make(domain: tcp_domain, host: '', port: 1234) }
          before do
            allow_any_instance_of(RouteValidator).to receive(:validate)
          end

          it 'returns a NOT_FOUND (404)' do
            get "/v2/routes/reserved/domain/#{tcp_route.domain_guid}"
            expect(last_response).to have_status_code(404)
          end

          context 'when the port is not reserved' do
            it 'returns a NOT_FOUND (404)' do
              get "/v2/routes/reserved/domain/#{tcp_route.domain_guid}?port=61234"
              expect(last_response).to have_status_code(404)
            end
          end

          context 'when the port is reserved' do
            it 'returns a NO_CONTENT (204)' do
              get "/v2/routes/reserved/domain/#{tcp_route.domain_guid}?port=#{tcp_route.port}"
              expect(last_response).to have_status_code(204)
            end

            context 'and the route has a different domain but same router group' do
              it 'returns a NO_CONTENT (204)' do
                get "/v2/routes/reserved/domain/#{tcp_2_domain.guid}?port=#{tcp_route.port}"
                expect(last_response).to have_status_code(204)
              end
            end
          end
        end

        context 'when a path is provided as a param' do
          context 'when the path does not exist' do
            it 'returns a NOT_FOUND (404)' do
              get "/v2/routes/reserved/domain/#{route.domain_guid}?host=#{route.host}&path=not_mypath"
              expect(last_response.status).to eq(404)
            end
          end

          context ' when the path does exist' do
            context 'when the path does not contain url encoding' do
              let(:path) { '/my_path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT (204)' do
                get "/v2/routes/reserved/domain/#{route.domain_guid}?host=#{route.host}&path=#{path}"
                expect(last_response.status).to eq(204)
              end
            end

            context 'when the path is url encoded' do
              let(:path) { '/my%20path' }
              let(:route) { Route.make(path: path) }

              it 'returns a NO_CONTENT' do
                uri_encoded_path = '%2Fmy%2520path'
                get "/v2/routes/reserved/domain/#{route.domain_guid}?host=#{route.host}&path=#{uri_encoded_path}"
                expect(last_response.status).to eq(204)
              end
            end
          end
        end
      end
    end

    describe 'PUT /v2/routes/:guid/apps/:app_guid' do
      let(:route) { Route.make }
      let(:process) { ProcessModelFactory.make(space: route.space) }
      let(:developer) { make_developer_for_space(route.space) }

      before do
        set_current_user(developer)
      end

      it 'associates the route and the app' do
        expect(route.reload.apps).to be_empty

        put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
        expect(last_response.status).to eq(201)

        expect(route.reload.apps).to match_array([process])

        mapping = RouteMappingModel.last
        expect(mapping.route).to eq(route)
        expect(mapping.app).to eq(process.app)
        expect(mapping.process_type).to eq(process.type)
        expect(mapping.app_port).to eq(8080)
      end

      context 'when the route does not exist' do
        it 'returns 404' do
          expect(route.reload.apps).to be_empty

          put "/v2/routes/not-a-route/apps/#{process.guid}", nil
          expect(last_response.status).to eq(404)
          expect(last_response.body).to include('RouteNotFound')

          expect(route.reload.apps).to be_empty
        end
      end

      context 'when the app does not exist' do
        it 'returns 404' do
          expect(route.reload.apps).to be_empty

          put "/v2/routes/#{route.guid}/apps/not-an-app", nil
          expect(last_response.status).to eq(404)
          expect(last_response.body).to include('AppNotFound')

          expect(route.reload.apps).to be_empty
        end
      end

      context 'when the user is not a SpaceDeveloper' do
        before do
          set_current_user(User.make)
        end

        it 'returns 403' do
          expect(route.reload.apps).to be_empty

          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(403)

          expect(route.reload.apps).to be_empty
        end
      end

      context 'when the route and app are already associated' do
        before do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
        end

        it 'reports success' do
          expect(route.reload.apps).to match_array([process])

          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(201)

          expect(route.reload.apps).to match_array([process])
        end
      end

      context 'when the app is in a different space' do
        let(:process) { ProcessModelFactory.make }

        it 'raises an error' do
          expect(route.reload.apps).to be_empty

          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match(/The requested app relation is invalid: the app and route must belong to the same space/)

          expect(route.reload.apps).to be_empty
        end
      end

      context 'when a route with a routing service is mapped to a non-diego app' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }
        let(:process) { ProcessModelFactory.make(space: route.space, diego: false) }

        it 'fails to add the route' do
          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match(/The requested app relation is invalid: .* - Route services are only supported for apps on Diego/)
        end
      end

      context 'when the app is diego' do
        let(:process) { ProcessModelFactory.make(diego: true, space: route.space, ports: [9797, 7979]) }

        it 'uses the first port for the app as the app_port' do
          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(201)

          mapping = RouteMappingModel.last
          expect(mapping.app_port).to eq(9797)
        end
      end

      describe 'tcp routes' do
        let(:tcp_domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
        let(:route) { Route.make(domain: tcp_domain, port: 9090, host: '') }

        it 'associates the route and the app' do
          expect(route.reload.apps).to be_empty

          put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
          expect(last_response.status).to eq(201)

          expect(route.reload.apps).to match_array([process])

          mapping = RouteMappingModel.last
          expect(mapping.route).to eq(route)
          expect(mapping.app).to eq(process.app)
          expect(mapping.process_type).to eq(process.type)
          expect(mapping.app_port).to eq(8080)
        end

        context 'when routing api is disabled' do
          before do
            route
            TestConfig.override(routing_api: nil)
          end

          it 'returns 403 for existing routes' do
            put "/v2/routes/#{route.guid}/apps/#{process.guid}", nil
            expect(last_response).to have_status_code(403)
            expect(decoded_response['description']).to include('Routing API is disabled')
          end
        end
      end
    end

    describe 'DELETE /v2/routes/:guid/apps/:app_guid' do
      let(:route) { Route.make }
      let(:process) { ProcessModelFactory.make(space: route.space) }
      let(:developer) { make_developer_for_space(route.space) }
      let!(:route_mapping) { RouteMappingModel.make(app: process.app, route: route, process_type: process.type) }

      before do
        set_current_user(developer)
      end

      it 'removes the association' do
        expect(route.reload.apps).to match_array([process])

        delete "/v2/routes/#{route.guid}/apps/#{process.guid}"
        expect(last_response.status).to eq(204)

        expect(route.reload.apps).to be_empty
        expect(route_mapping.exists?).to be_falsey
      end

      context 'when the route does not exist' do
        it 'returns a 404' do
          delete "/v2/routes/bogus-guid/apps/#{process.guid}"
          expect(last_response.status).to eq(404)
          expect(last_response.body).to include('RouteNotFound')
        end
      end

      context 'when the app does not exist' do
        it 'returns a 404' do
          delete "/v2/routes/#{route.guid}/apps/whoops"
          expect(last_response.status).to eq(404)
          expect(last_response.body).to include('AppNotFound')
        end
      end

      context 'when there is no route mapping' do
        before { route_mapping.destroy }

        it 'succeeds' do
          expect(route.reload.apps).to match_array([])

          delete "/v2/routes/#{route.guid}/apps/#{process.guid}"
          expect(last_response.status).to eq(204)

          expect(route.reload.apps).to be_empty
          expect(route_mapping.exists?).to be_falsey
        end
      end

      context 'when the user is not a SpaceDeveloper' do
        before do
          set_current_user(User.make)
        end

        it 'returns 403' do
          delete "/v2/routes/#{route.guid}/apps/#{process.guid}"
          expect(last_response).to have_status_code(403)
        end
      end
    end
  end
end
