require 'spec_helper'
require 'actions/manifest_route_update'

module VCAP::CloudController
  RSpec.describe ManifestRouteUpdate do
    let(:message) do
      ManifestRoutesUpdateMessage.new(
        routes: [
          { route: 'http://potato.tomato.avocado-toast.com/some-path' }
        ]
      )
    end

    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

    describe '#update' do
      let!(:app) { AppModel.make }
      let!(:process) { ProcessModel.make(app:) }
      let!(:another_process) { ProcessModel.make(app:) }

      before do
        TestConfig.override(kubernetes: {})
      end

      context 'when the route already exists' do
        let(:domain) { VCAP::CloudController::SharedDomain.make(name: 'tomato.avocado-toast.com') }
        let!(:route) { Route.make(host: 'potato', domain: domain, path: '/some-path', space: app.space) }

        context 'when the route is already mapped to the app' do
          let!(:route_mapping) do
            RouteMappingModel.make(app: app, route: route, app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
          end

          it 'does not attempt to re-map the route to the app' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.not_to(change { route_mapping.reload.updated_at })
          end

          context 'and a protocol is NOT provided' do
            let!(:route_mapping) do
              RouteMappingModel.make(app: app, route: route, protocol: 'http2', app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
            end

            it 'does NOT change the route mapping protocol back to the default (manifests are NOT declarative)' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.not_to(change { route_mapping.reload.updated_at })
            end
          end

          context 'when the new route has a protocol' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://potato.tomato.avocado-toast.com/some-path', protocol: 'http2' }
                ]
              )
            end

            before do
              route2 = Route.make(host: 'potatotwo', domain: domain, path: '/some-path', space: app.space)
              RouteMappingModel.make(app: app, route: route2)
            end

            it 'updates (or recreates) the route mapping with the new protocol' do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)

              route_mappings = app.reload.route_mappings

              expect(route_mappings.count).to eq(2)
              mapped_route = route_mappings.find { |rm| rm.route == route }
              expect(mapped_route.protocol).to eq('http2')
            end
          end
        end

        context 'when the route is not mapped to the app' do
          it 'uses the existing route and creates a new mapping' do
            num_routes = Route.count
            num_maps = app.routes.length
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            routes = app.reload.routes
            expect(routes.length).to eq(num_routes + 0)
            expect(Route.count).to eq(num_maps + 1)

            route = routes.first
            expect(route.host).to eq 'potato'
            expect(route.domain.name).to eq 'tomato.avocado-toast.com'
            expect(route.path).to eq '/some-path'
          end

          context 'when the route has a protocol specified' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://potato.tomato.avocado-toast.com/some-path', protocol: 'http2' }
                ]
              )
            end

            it 'uses the existing route and creates a new mapping with protocol' do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)

              routes = app.reload.routes
              route = routes.first
              mapping = route.route_mappings_dataset.first(app:)
              expect(mapping).not_to be_nil
              expect(mapping.protocol).to eq('http2')
            end
          end

          context 'when the route and app are in different spaces' do
            let!(:outside_app) { AppModel.make }

            it 'raises a route invalid error' do
              expect do
                ManifestRouteUpdate.update(outside_app.guid, message, user_audit_info)
              end.to raise_error(VCAP::CloudController::ManifestRouteUpdate::InvalidRoute,
                                 'Routes cannot be mapped to destinations in different spaces')
            end
          end

          context 'when the route is shared' do
            let!(:route_share) { RouteShare.new }
            let!(:outside_app) { AppModel.make }
            let!(:shared_route) { route_share.create(route, [outside_app.space], user_audit_info) }

            it 'succeeds after route share' do
              expect do
                ManifestRouteUpdate.update(outside_app.guid, message, user_audit_info)
              end.not_to raise_error
            end
          end
        end
      end

      context 'when the route does not already exist' do
        context 'when the domain exists' do
          before do
            VCAP::CloudController::SharedDomain.make(name: 'tomato.avocado-toast.com')
          end

          it 'creates and maps the route to the app' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.to change { app.reload.routes.length }.by(1)
            routes = app.reload.routes
            expect(routes.length).to eq 1

            route = routes.first

            expect(route.host).to eq 'potato'
            expect(route.domain.name).to eq 'tomato.avocado-toast.com'
            expect(route.path).to eq '/some-path'
          end

          context 'when using a host that matches the first segment of the domain' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://tomato.tomato.avocado-toast.com/some-path' }
                ]
              )
            end

            it 'creates and maps the route to the app' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq 1

              route = routes.first

              expect(route.host).to eq 'tomato'
              expect(route.domain.name).to eq 'tomato.avocado-toast.com'
              expect(route.path).to eq '/some-path'
            end
          end

          context 'when using a private domain but no host' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://private.avocado-toast.com' }
                ]
              )
            end

            before do
              VCAP::CloudController::PrivateDomain.make(owning_organization: app.space.organization, name: 'private.avocado-toast.com')
            end

            it 'creates and maps the route to the app' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq 1

              route = routes.first

              expect(route.host).to eq ''
              expect(route.domain.name).to eq 'private.avocado-toast.com'
            end
          end

          context 'when using a wildcard host with a private domain' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://*.private.avocado-toast.com' }
                ]
              )
            end

            before do
              VCAP::CloudController::PrivateDomain.make(owning_organization: app.space.organization, name: 'private.avocado-toast.com')
            end

            it 'creates and maps the route to the app' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq 1

              route = routes.first

              expect(route.host).to eq '*'
              expect(route.domain.name).to eq 'private.avocado-toast.com'
            end
          end

          context 'when using a wildcard host with a shared domain' do
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://*.tomato.avocado-toast.com' }
                ]
              )
            end

            it 'raises an error' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to raise_error(CloudController::Errors::ApiError)
            end
          end

          context 'when the route is a tcp route' do
            let(:ra_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group: rg) }
            let(:rg) { instance_double(VCAP::CloudController::RoutingApi::RouterGroup, type: 'tcp', reservable_ports: [1234, 1235]) }
            let!(:tcp_domain) { SharedDomain.make(name: 'tcp.tomato.avocado-toast.com', router_group_guid: '123') }
            let(:message) do
              ManifestRoutesUpdateMessage.new(
                routes: [
                  { route: 'http://tcp.tomato.avocado-toast.com:1234' }
                ]
              )
            end

            before do
              allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(ra_client)
              allow(ra_client).to receive(:enabled?).and_return(true)
            end

            it 'creates and maps the route to the app' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq(1)

              route = routes.find { |r| r.port == 1234 }

              expect(route.host).to eq('')
              expect(route.domain.name).to eq('tcp.tomato.avocado-toast.com')
            end

            context 'but there is another tcp route with a different port' do
              let!(:other_route) { Route.make(domain: tcp_domain, host: '', space: app.space, port: 1235) }
              let!(:other_route_mapping) do
                RouteMappingModel.make(app: app, route: other_route)
              end

              it 'creates and maps the route to the app' do
                expect do
                  ManifestRouteUpdate.update(app.guid, message, user_audit_info)
                end.to change { app.reload.routes.length }.by(1)
                routes = app.reload.routes
                expect(routes.length).to eq(2)

                route = routes.find { |r| r.port == 1234 }

                expect(route.host).to eq('')
                expect(route.domain.name).to eq('tcp.tomato.avocado-toast.com')
              end
            end

            context 'and an http protocol is given' do
              let(:message) do
                ManifestRoutesUpdateMessage.new(
                  routes: [
                    { route: 'http://tcp.tomato.avocado-toast.com:1234', protocol: 'http2' }
                  ]
                )
              end

              it 'throws an error' do
                expect do
                  ManifestRouteUpdate.update(app.guid, message, user_audit_info)
                end.to raise_error(VCAP::CloudController::UpdateRouteDestinations::Error, 'Cannot use \'http2\' protocol for tcp routes; valid options are: [tcp].')
              end
            end
          end

          context 'when route creation feature is disabled' do
            before do
              VCAP::CloudController::FeatureFlag.make(name: 'route_creation', enabled: false, error_message: 'nope')
            end

            it 'raises an unauthorized error' do
              expect do
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              end.to raise_error(CloudController::Errors::ApiError)
            end
          end
        end

        context 'when the domain does not exist' do
          it 'raises a route invalid error' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.to raise_error(VCAP::CloudController::ManifestRouteUpdate::InvalidRoute,
                               "No domains exist for route #{message.routes.first[:route]}")
          end
        end

        context 'when the organization of the app does not have access to the domain' do
          before do
            VCAP::CloudController::PrivateDomain.make(name: 'tomato.avocado-toast.com')
          end

          it 'raises an error' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.to raise_error(ManifestRouteUpdate::InvalidRoute, /Domain .* is not available/)
          end
        end
      end

      context 'when multiple domains exist' do
        let!(:specific_domain) { VCAP::CloudController::SharedDomain.make(name: 'tomato.avocado-toast.com') }
        let!(:broader_domain) { VCAP::CloudController::SharedDomain.make(name: 'avocado-toast.com') }

        it 'creates the route in the most specific domain' do
          ManifestRouteUpdate.update(app.guid, message, user_audit_info)

          routes = app.reload.routes
          expect(routes.length).to eq(1)
          expect(routes.first.domain.name).to eq specific_domain.name
        end
      end

      context 'when there is no host provided' do
        before do
          VCAP::CloudController::SharedDomain.make(name: 'potato.tomato.avocado-toast.com')
        end

        it('raises an error indicating that a host must be provided') do
          expect do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)
          end.to raise_error(ManifestRouteUpdate::InvalidRoute, /Routes in shared domains must have a host defined/)
        end
      end

      context 'when the host is invalid' do
        let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'avocado-toast.com') }
        let(:message) do
          ManifestRoutesUpdateMessage.new(
            routes: [
              { route: 'http://not good host 🌝.avocado-toast.com/some-path' }
            ]
          )
        end

        it('raises an error indicating that the host format is invalid') do
          expect do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)
          end.to raise_error(ManifestRouteUpdate::InvalidRoute, /Host format is invalid/)
        end
      end

      context 'when route options are provided' do
        let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'tomato.avocado-toast.com') }

        before do
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
        end

        context 'when creating a new route with loadbalancing options' do
          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { loadbalancing: 'round-robin' }
                }
              ]
            )
          end

          it 'creates the route with the specified loadbalancing option' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            routes = app.reload.routes
            expect(routes.length).to eq(1)

            route = routes.first
            expect(route.options).to include({ 'loadbalancing' => 'round-robin' })
          end
        end

        context 'when creating a new route with hash loadbalancing and hash_header' do
          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: {
                    loadbalancing: 'hash',
                    hash_header: 'X-User-ID'
                  }
                }
              ]
            )
          end

          it 'creates the route with hash loadbalancing options' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            routes = app.reload.routes
            expect(routes.length).to eq(1)

            route = routes.first
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID' })
          end
        end

        context 'when creating a new route with hash loadbalancing, hash_header, and hash_balance' do
          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: {
                    loadbalancing: 'hash',
                    hash_header: 'X-Session-ID',
                    hash_balance: '2.5'
                  }
                }
              ]
            )
          end

          it 'creates the route with all hash loadbalancing options' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            routes = app.reload.routes
            expect(routes.length).to eq(1)

            route = routes.first
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-Session-ID', 'hash_balance' => '2.5' })
          end
        end

        context 'when creating a new route with hash loadbalancing but missing hash_header' do
          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { loadbalancing: 'hash' }
                }
              ]
            )
          end

          it 'raises an error indicating hash_header is required' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.to raise_error(ManifestRouteUpdate::InvalidRoute, /Hash header must be present when loadbalancing is set to hash./)
          end
        end

        context 'when updating an existing route with new loadbalancing options' do
          let!(:route) { Route.make(host: 'potato', domain: domain, path: '/some-path', space: app.space) }
          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { loadbalancing: 'least-connection' }
                }
              ]
            )
          end

          it 'updates the existing route with the new loadbalancing option' do
            expect do
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            end.not_to(change(Route, :count))

            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'least-connection' })
          end
        end

        context 'when updating an existing route from round-robin to hash' do
          let!(:route) do
            Route.make(
              host: 'potato',
              domain: domain,
              path: '/some-path',
              space: app.space,
              options: { loadbalancing: 'round-robin' }
            )
          end

          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: {
                    loadbalancing: 'hash',
                    hash_header: 'X-User-ID'
                  }
                }
              ]
            )
          end

          it 'updates the route to hash loadbalancing with hash_header' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID' })
          end
        end

        context 'when updating an existing hash route with new hash_header' do
          let!(:route) do
            Route.make(
              host: 'potato',
              domain: domain,
              path: '/some-path',
              space: app.space,
              options: {
                loadbalancing: 'hash',
                hash_header: 'X-Old-Header',
                hash_balance: '2.0'
              }
            )
          end

          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { hash_header: 'X-New-Header' }
                }
              ]
            )
          end

          it 'updates only the hash_header while keeping other options' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-New-Header', 'hash_balance' => '2.0' })
          end
        end

        context 'when updating an existing hash route with new hash_balance' do
          let!(:route) do
            Route.make(
              host: 'potato',
              domain: domain,
              path: '/some-path',
              space: app.space,
              options: {
                loadbalancing: 'hash',
                hash_header: 'X-User-ID',
                hash_balance: '2.0'
              }
            )
          end

          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { hash_balance: '5.0' }
                }
              ]
            )
          end

          it 'updates only the hash_balance while keeping other options' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID', 'hash_balance' => '5.0' })
          end
        end

        context 'when updating an existing hash route to remove loadbalancing' do
          let!(:route) do
            Route.make(
              host: 'potato',
              domain: domain,
              path: '/some-path',
              space: app.space,
              options: {
                loadbalancing: 'hash',
                hash_header: 'X-User-ID',
                hash_balance: '2.0'
              }
            )
          end

          let(:message) do
            ManifestRoutesUpdateMessage.new(
              routes: [
                {
                  route: 'http://potato.tomato.avocado-toast.com/some-path',
                  options: { loadbalancing: nil }
                }
              ]
            )
          end

          it 'removes loadbalancing and hash options' do
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)

            route.reload
            expect(route.options).to eq({})
            expect(route.options).not_to have_key('loadbalancing')
            expect(route.options).not_to have_key('hash_header')
            expect(route.options).not_to have_key('hash_balance')
          end
        end
      end
    end
  end
end
