require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RoutesController do
    let(:routing_api_client) { double('routing_api_client') }
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
    let(:app_event_repository) { instance_double(Repositories::Runtime::AppEventRepository) }
    let(:route_event_repository) { instance_double(Repositories::Runtime::RouteEventRepository) }

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
      it { expect(described_class).to be_queryable_by(:host) }
      it { expect(described_class).to be_queryable_by(:domain_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
      it { expect(described_class).to be_queryable_by(:path) }
      it { expect(described_class).to be_queryable_by(:port) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes(
          host: { type: 'string', default: '' },
          domain_guid: { type: 'string', required: true },
          space_guid: { type: 'string', required: true },
          app_guids: { type: '[string]' },
          path: { type: 'string' },
          port: { type: 'integer' }
        )
      end
      it do
        expect(described_class).to have_updatable_attributes(
          host: { type: 'string' },
          domain_guid: { type: 'string' },
          space_guid: { type: 'string' },
          app_guids: { type: '[string]' },
          path: { type: 'string' },
          port: { type: 'integer' }
        )
      end
    end

    describe 'Permissions' do
      context 'with a custom domain' do
        include_context 'permissions'

        before do
          @domain_a = PrivateDomain.make(owning_organization: @org_a)
          @obj_a = Route.make(domain: @domain_a, space: @space_a)

          @domain_b = PrivateDomain.make(owning_organization: @org_b)
          @obj_b = Route.make(domain: @domain_b, space: @space_b)
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
      let(:http_domain) { SharedDomain.make }
      let(:space) { Space.make }

      let(:routing_api_client) { double('routing_api_client') }
      let(:router_group) {
        RoutingApi::RouterGroup.new({
                                        'guid' => 'tcp-guid',
                                        'type' => 'tcp',
                                        'reservable_ports' => '1024-65535'
                                    })
      }
      let(:user) { User.make }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
          and_return(routing_api_client)
        allow(routing_api_client).to receive(:router_group).and_return(router_group)
      end

      it 'returns the RouteHostTaken message when no paths are used' do
        taken_host = 'someroute'
        Route.make(host: taken_host, domain: http_domain)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: http_domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response).to have_status_code(400)
        expect(decoded_response['code']).to eq(210003)
      end

      it 'returns the RoutePortTaken message when ports conflict' do
        taken_port = 1024
        post '/v2/routes', MultiJson.dump(host: '', domain_guid: tcp_domain.guid, space_guid: space.guid, port: taken_port), json_headers(admin_headers)

        post '/v2/routes', MultiJson.dump(host: '', domain_guid: tcp_domain.guid, space_guid: space.guid, port: taken_port), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210005)
      end

      it 'returns the RoutePathTaken message when paths conflict' do
        taken_host = 'someroute'
        path = '/%2Fsome%20path'
        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: http_domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        post '/v2/routes', MultiJson.dump(host: taken_host, domain_guid: http_domain.guid, space_guid: space.guid, path: path), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210004)
      end

      it 'returns the SpaceQuotaTotalRoutesExceeded message' do
        quota_definition = SpaceQuotaDefinition.make(total_routes: 0, organization: space.organization)
        space.space_quota_definition = quota_definition
        space.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310005)
      end

      it 'returns the OrgQuotaTotalRoutesExceeded message' do
        quota_definition = space.organization.quota_definition
        quota_definition.total_routes = 0
        quota_definition.save

        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(310006)
      end

      it 'returns the RouteInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample!*', domain_guid: http_domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(210001)
      end

      it 'returns RouteInvalid when port is specified with an http domain' do
        post '/v2/routes', MultiJson.dump(domain_guid: http_domain.guid, space_guid: space.guid, port: 8080), headers_for(user)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Port is supported for domains of TCP router groups only.')
      end

      it 'returns RouteInvalid when generate_port is queried with an http domain' do
        post '/v2/routes?generate_port=true', MultiJson.dump(domain_guid: http_domain.guid, space_guid: space.guid), headers_for(user)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Port is supported for domains of TCP router groups only.')
      end

      it 'returns RouteInvalid when generate_port is false and port not provided' do
        post '/v2/routes?generate_port=false', MultiJson.dump(domain_guid: tcp_domain.guid, space_guid: space.guid), headers_for(user)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('For TCP routes you must specify a port or request a random one.')
      end

      it 'returns the a path cannot contain only "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid, path: '/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path cannot be a single slash')
      end

      it 'returns the a path must start with a "/"' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid, path: 'a/'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('the path must start with a "/"')
      end

      it 'returns the a path cannot contain "?" message for paths' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
        expect(decoded_response['description']).to include('illegal "?" character')
      end

      it 'returns the PathInvalid message' do
        post '/v2/routes', MultiJson.dump(host: 'myexample', domain_guid: http_domain.guid, space_guid: space.guid, path: '/v2/zak?'), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130004)
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ apps: [:get, :put, :delete] })
      end

      context 'with Docker app' do
        before do
          allow(route_event_repository).to receive(:record_route_update)
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let(:organization) { Organization.make }
        let(:http_domain) { PrivateDomain.make(owning_organization: organization) }
        let(:space) { Space.make(organization: organization) }
        let(:route) { Route.make(domain: http_domain, space: space) }
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
      let(:route) { Route.make }

      before do
        allow(route_event_repository).to receive(:record_route_delete_request)
        allow(app_event_repository).to receive(:record_unmap_route)
      end

      it 'deletes the route' do
        delete "v2/routes/#{route.guid}", {}, admin_headers_for(user)

        expect(last_response.status).to eq 204
        expect(route.exists?).to be_falsey
      end

      context 'when async=true' do
        it 'deletes the route in a background job' do
          delete "v2/routes/#{route.guid}?async=true", {}, admin_headers_for(user)

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
          delete "v2/routes/#{route.guid}?recursive=true&async=true", {}, admin_headers_for(user)
          expect(route_delete).to have_received(:delete_async).with(route: route, recursive: true)
        end

        it 'passes recursive true to sync deletes' do
          allow(route_delete).to receive(:delete_sync)
          delete "v2/routes/#{route.guid}?recursive=true&async=false", {}, admin_headers_for(user)
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
          delete "v2/routes/#{route.guid}", {}, admin_headers

          expect(last_response).to have_status_code 400
          expect(last_response.body).to include 'AssociationNotEmpty'
          expect(last_response.body).to include
          'Please delete the service_instance associations for your routes'
        end
      end
    end

    describe 'POST /v2/routes' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:domain_guid) { SharedDomain.make.guid }
      let(:host) { 'example' }
      let(:port) { 1050 }
      let(:req) { {
          domain_guid: domain_guid,
          space_guid: space.guid,
          host: host,
          port: port,
          path: ''
      } }
      let(:route_attrs) { { 'port' => port, 'host' => host, 'path' => '' } }
      let(:tcp_route_validator) { double('tcp_route_validator', validate: nil) }

      before do
        allow(route_event_repository).to receive(:record_route_create)
        space.organization.add_user(user)
        space.add_developer(user)
        allow(RouteValidator).to receive(:new).with(routing_api_client, domain_guid, route_attrs).and_return(tcp_route_validator)
      end

      context 'when the domain is a HTTP Domain' do
        context 'when the domain is a shared domain' do
          let(:shared_domain) { SharedDomain.make }
          let(:domain_guid) { shared_domain.guid }

          context 'and a route already exists with the same host' do
            before do
              Route.make(domain: shared_domain, host: host, space: space)
            end

            context 'and a user tries to create another route in a different space' do
              let(:another_space) { Space.make }
              let(:route_attrs) { { 'port' => nil, 'host' => host, 'path' => '/foo' } }
              let(:req) do
                {
                  domain_guid: shared_domain.guid,
                  space_guid: another_space.guid,
                  host: host,
                  port: nil,
                  path: '/foo'
                }
              end

              before do
                another_space.organization.add_user(user)
                another_space.add_developer(user)
              end

              it 'fails with an RouteInvalid' do
                post '/v2/routes', MultiJson.dump(req), headers_for(user)

                expect(last_response).to have_status_code(400)
                expect(decoded_response['description']).
                  to include('Routes for this host and domain have been reserved for another space')
              end
            end
          end
        end

        context 'domain is invalid' do
          before do
            allow(tcp_route_validator).to receive(:validate).
              and_raise(RouteValidator::DomainInvalid.new('domain error'))
          end

          it 'returns an error' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('domain error')
            expect(decoded_response['error_code']).to eq 'CF-DomainInvalid'
          end
        end
      end

      context 'when the domain is a TCP Domain' do
        let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
        let(:domain_guid) {domain.guid}

        context 'when the routing api client raises a UaaUnavailable error' do
          before do
            allow(tcp_route_validator).to receive(:validate).
              and_raise(RoutingApi::Client::UaaUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'The UAA service is currently unavailable'
          end
        end

        context 'when the routing api is disabled' do
          before do
            allow(tcp_route_validator).to receive(:validate).
              and_raise(RoutingApi::Client::RoutingApiDisabled)
          end
          it 'returns a 403' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(403)
            expect(last_response.body).to include 'Support for TCP routing is disabled'
          end
        end

        context 'when the routing api client raises a RoutingApiUnavailable error' do
          before do
            allow(tcp_route_validator).to receive(:validate).
              and_raise(RoutingApi::Client::RoutingApiUnavailable)
          end

          it 'returns a 503 Service Unavailable' do
            post '/v2/routes', MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(503)
            expect(last_response.body).to include 'Routing API is currently unavailable'
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

        context 'query params' do
          context 'generate_port' do
            let(:port_override_warning) { 'Specified+port+ignored.+Random+port+generated.' }

            it 'fails with InvalidRequest when generate_port is not "true" or "false"' do
              post '/v2/routes?generate_port=lol', MultiJson.dump(req), headers_for(user)

              expect(last_response.status).to eq(400)
            end

            context 'when the routing api is disabled' do
              before do
                allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).and_return(nil)
              end
              it 'returns a 403' do
                post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                expect(last_response).to have_status_code(403)
                expect(last_response.body).to include 'Support for TCP routing is disabled'
              end
            end

            context 'when the router group runs out of ports' do
              let(:generated_port) { -1 }
              let(:domain) { SharedDomain.make(router_group_guid: tcp_group_3) }
              let(:domain_guid) { domain.guid }
              let(:route_attrs) { { 'port' => generated_port, 'host' => host, 'path' => '' } }

              before do
                allow_any_instance_of(PortGenerator).to receive(:generate_port).and_return(generated_port)
              end

              it 'returns 403' do
                post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                expect(last_response.status).to eq(403)
                expect(last_response.body).to include('There are no more ports available for router group: TCP3. Please contact your administrator for more information.')
              end
            end

            context 'the body does not provide a port' do
              let(:port) { nil }
              let(:no_port_error) { 'For TCP routes you must specify a port or request a random one.' }

              context 'generate_port is "true"' do
                let(:generated_port) { 10005 }
                let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
                let(:domain_guid) { domain.guid }
                let(:route_attrs) { { 'port' => generated_port, 'host' => host, 'path' => '' } }

                before do
                  allow_any_instance_of(PortGenerator).to receive(:generate_port).and_return(generated_port)
                end

                it 'generates a port without warning' do
                  post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                  expect(last_response.status).to eq(201)
                  expect(last_response.body).to include("\"port\": #{generated_port}")
                  expect(last_response.headers).not_to include('X-CF-Warnings')
                end
              end

              context 'generate_port is "false"' do
                before do
                  allow(RouteValidator).to receive(:new).
                    with(routing_api_client, domain_guid, route_attrs).
                    and_raise(RouteValidator::RouteInvalid.new('For TCP routes you must specify a port or request a random one.'))
                end

                it 'raise a error' do
                  post '/v2/routes?generate_port=false', MultiJson.dump(req), headers_for(user)

                  expect(last_response.status).to eq(400)
                  expect(last_response.body).to include(no_port_error)
                end
              end
            end

            context 'body provides a port' do
              context 'generate_port is "true"' do
                let(:generated_port) { 14098 }
                let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
                let(:domain_guid) { domain.guid }
                let(:route_attrs) { { 'port' => generated_port, 'host' => host, 'path' => '' } }

                before do
                  allow_any_instance_of(PortGenerator).to receive(:generate_port).and_return(generated_port)
                end

                it 'creates a route with a generated random port with a warning' do
                  post '/v2/routes?generate_port=true', MultiJson.dump(req), headers_for(user)

                  expect(last_response.status).to eq(201)
                  expect(last_response.body).to include("\"port\": #{generated_port}")
                  expect(last_response.headers).to include('X-CF-Warnings')
                  expect(last_response.headers['X-CF-Warnings']).to include(port_override_warning)
                end
              end

              context 'generate_port is "false"' do
                it 'creates a route with the requested port' do
                  post '/v2/routes?generate_port=false', MultiJson.dump(req), headers_for(user)

                  expect(last_response.status).to eq(201)
                  expect(last_response.body).to include("\"port\": #{port}")
                end
              end
            end
          end
        end
      end
    end

    describe 'PUT /v2/routes/:guid' do
      let(:space) { Space.make }
      let(:user) { User.make }
      let(:domain) { SharedDomain.make }
      let(:domain_guid) { domain.guid }
      let(:tcp_route_validator) { double(:tcp_route_validator, validate: nil) }

      before do
        space.organization.add_user(user)
        space.add_developer(user)
        allow(RouteValidator).to receive(:new).with(routing_api_client, domain_guid, route_attrs).and_return(tcp_route_validator)
        allow(route_event_repository).to receive(:record_route_update)
      end

      describe 'tcp routes' do
        let(:port) { 18000 }
        let(:new_port) { 18001 }
        let(:route) { Route.make(space: space, domain: domain, port: port) }
        let(:req) { {
          port: new_port,
        } }
        let(:route_attrs) { { 'port' => new_port, 'host' => nil, 'path' => nil } }

        context 'when the TCP Route is not valid' do
          before do
            allow(tcp_route_validator).to receive(:validate).
              and_raise(RouteValidator::DomainInvalid.new('domain error'))
          end

          it 'returns an error' do
            put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(400)
            expect(decoded_response['description']).to include('domain error')
            expect(decoded_response['error_code']).to eq 'CF-DomainInvalid'
          end
        end

        context 'when associating with app' do
          let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }
          let(:req) { '' }
          let(:app_obj) { AppFactory.make(space: route.space) }

          it 'allows updating route' do
            put "/v2/routes/#{route.guid}/apps/#{app_obj.guid}", MultiJson.dump(req), headers_for(user)

            expect(last_response).to have_status_code(201)
            expect(app_obj.reload.routes.first).to eq(route)
          end
        end

        context 'when updating a route with a new port value that is not null' do
          let(:req) { {
              port: new_port,
          } }

          context 'with a domain with a router_group_guid and type tcp' do
            let(:domain) { SharedDomain.make(router_group_guid: tcp_group_1) }

            it 'updates the route' do
              put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

              expect(last_response).to have_status_code(201)
              expect(decoded_response['entity']['port']).to eq(new_port)
            end

            context 'with the current port' do
              let(:new_port) { port }

              it 'updates the route' do
                put "/v2/routes/#{route.guid}", MultiJson.dump(req), headers_for(user)

                expect(last_response).to have_status_code(201)
                expect(decoded_response['entity']['port']).to eq(new_port)
              end
            end
          end

          context 'when the routing api client raises a UaaUnavailable error' do
            let(:domain) { SharedDomain.make(router_group_guid: 'router-group') }
            before do
              allow(tcp_route_validator).to receive(:validate).
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
              allow(tcp_route_validator).to receive(:validate).
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

      it 'should contain links to the route_mappings resource' do
        route_guid = route.guid
        get 'v2/routes', {}, admin_headers

        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['entity']['route_mappings_url']).
          to eq("/v2/routes/#{route_guid}/route_mappings")
      end

      describe 'Filtering with Organization Guid' do
        context 'When Organization Guid Not Present' do
          it 'Return Resource length zero' do
            get 'v2/routes?q=organization_guid:notpresent', {}, admin_headers
            expect(last_response.status).to eq(200)
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

          it 'Allows filtering at organization level with multiple guids' do
            org_guid = organization.guid
            route_guid = route.guid
            route1_guid = route1.guid

            org2_guid = organization2.guid
            route2_guid = route2.guid

            get "v2/routes?q=organization_guid%20IN%20#{org_guid},#{org2_guid}", {}, admin_headers

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
      let(:app_obj) { AppFactory.make(space: route.space) }
      let!(:app_route_mapping) { RouteMapping.make(route: route, app: app_obj) }

      it 'lists the route mappings' do
        get "v2/routes/#{route.guid}/route_mappings", {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(decoded_response['resources'].length).to eq(1)
        expect(decoded_response['resources'][0]['metadata']['guid']).to eq app_route_mapping.guid
      end

      context 'when user has no access to the route' do
        let(:user) { User.make }

        it 'returns forbidden error' do
          get "v2/routes/#{route.guid}/route_mappings", {}, headers_for(user)
          expect(last_response).to have_status_code(403)
        end
      end

      context 'when a route has no route_mappings' do
        let(:route_2) { Route.make(domain: domain, space: space) }

        it 'returns an empty collection' do
          get "v2/routes/#{route_2.guid}/route_mappings", {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(decoded_response['resources'].length).to eq(0)
        end
      end

      context 'when an non existing route is specified' do
        it 'returns resource not found' do
          get 'v2/routes/non-existing-route-guid/route_mappings', {}, admin_headers
          expect(last_response).to have_status_code(404)
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
