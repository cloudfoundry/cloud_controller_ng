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
      let!(:process) { ProcessModel.make(app: app) }
      let!(:another_process) { ProcessModel.make(app: app) }

      before do
        TestConfig.override(kubernetes: {})
      end

      context 'when the route already exists' do
        let(:domain) { VCAP::CloudController::SharedDomain.make(name: 'tomato.avocado-toast.com') }
        let!(:route) { Route.make(host: 'potato', domain: domain, path: '/some-path', space: app.space) }

        context 'when the route is already mapped to the app' do
          let!(:route_mapping) {
            RouteMappingModel.make(app: app, route: route, app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
          }

          it 'does not attempt to re-map the route to the app' do
            expect {
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            }.not_to change { route_mapping.reload.updated_at }
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

          context 'when the route and app are in different spaces' do
            let!(:outside_app) { AppModel.make }
            it 'raises a route invalid error' do
              expect {
                ManifestRouteUpdate.update(outside_app.guid, message, user_audit_info)
              }.to raise_error(VCAP::CloudController::ManifestRouteUpdate::InvalidRoute,
                'Routes cannot be mapped to destinations in different spaces')
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
            expect {
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            }.to change { app.reload.routes.length }.by(1)
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
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to change { app.reload.routes.length }.by(1)
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
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to change { app.reload.routes.length }.by(1)
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
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to change { app.reload.routes.length }.by(1)
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
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to raise_error(CloudController::Errors::ApiError)
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
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq(1)

              route = routes.find { |r| r.port == 1234 }

              expect(route.host).to eq('')
              expect(route.domain.name).to eq('tcp.tomato.avocado-toast.com')
            end

            context 'but there is another tcp route with a different port' do
              let!(:other_route) { Route.make(domain: tcp_domain, host: '', space: app.space, port: 1235) }
              let!(:other_route_mapping) {
                RouteMappingModel.make(app: app, route: other_route)
              }

              it 'creates and maps the route to the app' do
                expect {
                  ManifestRouteUpdate.update(app.guid, message, user_audit_info)
                }.to change { app.reload.routes.length }.by(1)
                routes = app.reload.routes
                expect(routes.length).to eq(2)

                route = routes.find { |r| r.port == 1234 }

                expect(route.host).to eq('')
                expect(route.domain.name).to eq('tcp.tomato.avocado-toast.com')
              end
            end
          end

          context 'when route creation feature is disabled' do
            before do
              VCAP::CloudController::FeatureFlag.make(name: 'route_creation', enabled: false, error_message: 'nope')
            end

            it 'raises an unauthorized error' do
              expect {
                ManifestRouteUpdate.update(app.guid, message, user_audit_info)
              }.to raise_error(CloudController::Errors::ApiError)
            end
          end
        end

        context 'when the domain does not exist' do
          it 'raises a route invalid error' do
            expect {
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            }.to raise_error(VCAP::CloudController::ManifestRouteUpdate::InvalidRoute,
              "No domains exist for route #{message.routes.first[:route]}")
          end
        end

        context 'when the organization of the app does not have access to the domain' do
          before do
            VCAP::CloudController::PrivateDomain.make(name: 'tomato.avocado-toast.com')
          end

          it 'raises an error' do
            expect {
              ManifestRouteUpdate.update(app.guid, message, user_audit_info)
            }.to raise_error(ManifestRouteUpdate::InvalidRoute, /Domain .* is not available/)
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
          expect {
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)
          }.to raise_error(ManifestRouteUpdate::InvalidRoute, /Routes in shared domains must have a host defined/)
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
          expect {
            ManifestRouteUpdate.update(app.guid, message, user_audit_info)
          }.to raise_error(ManifestRouteUpdate::InvalidRoute, /Host format is invalid/)
        end
      end
    end
  end
end
