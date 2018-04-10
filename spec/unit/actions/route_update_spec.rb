require 'spec_helper'
require 'actions/route_update'

module VCAP::CloudController
  RSpec.describe RouteUpdate do
    subject(:route_update) { RouteUpdate.new(user_audit_info) }

    let(:message) { ManifestRoutesMessage.new({
      routes: [
        {'route': 'http://host.sub.some-domain.com:8080/some-path'}
      ]
      })
    }

    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

    describe '#update' do

      let!(:app) { AppModel.make }
      let!(:process) { ProcessModel.make(app: app) }

      context 'when the request is valid' do
        context 'when the route already exists' do
          let!(:domain) { VCAP::CloudController::SharedDomain.make(name: 'sub.some-domain.com') }
          let!(:route) { Route.make(host: 'host', domain: domain, path: '/some-path', space: app.space) }

          context 'when the route is already mapped to the app' do
            before do
              RouteMappingModel.make(app: app, route: route, app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
            end

            it 'throws an exception instead of adding a new route' do
              expect {
                route_update.update(app.guid, message)
              }.to raise_error(VCAP::CloudController::RouteMappingCreate::DuplicateRouteMapping, 'Duplicate Route Mapping - Only one route mapping may exist for an application, route, and port')
            end
          end

          context 'when the route is not mapped to the app' do

            it 'uses the existing route and creates a new map' do
              num_routes = Route.count
              num_maps = app.routes.length
              route_update.update(app.guid, message)

              routes = app.reload.routes
              # expect{....}.to change{[...]}.by([0, 1]) isn't working
              expect(routes.length).to eq(num_routes + 0)
              expect(Route.count).to eq(num_maps + 1)

              route = routes.first
              expect(route.host).to eq 'host'
              expect(route.domain.name).to eq 'sub.some-domain.com'
              expect(route.path).to eq '/some-path'
            end
          end
        end

        context 'when the route does not already exist' do
          let!(:domain) { VCAP::CloudController::SharedDomain.make(name: domain_name) }

          context 'when the domain exists' do
            let(:domain_name) {'sub.some-domain.com' }

            it 'creates and maps the route to the app' do
              expect{
                route_update.update(app.guid, message)
              }.to change { app.reload.routes.length }.by(1)
              routes = app.reload.routes
              expect(routes.length).to eq 1

              route = routes.first

              expect(route.host).to eq 'host'
              expect(route.domain.name).to eq 'sub.some-domain.com'
              expect(route.path).to eq '/some-path'
            end
          end

          context "when the domain doesn't exist" do
            let(:domain_name) {'drooper.snork.com' }

            it 'raises a route invalid error' do
              expect{
                route_update.update(app.guid, message)
              }.to raise_error(VCAP::CloudController::RouteValidator::RouteInvalid,
                "no domains exist for route #{message.routes.first[:route]}")
            end
          end

        end

        context 'when multiple domains match' do
          # is this even possible?
        end

      end

      context 'when the request is invalid' do
        context 'when the domain does not exist' do
        end

        context 'when the app is in an org that does not have access to the provided domain' do
        end

        context 'when there is no host provided' do
        end

        context 'when the host is invalid' do
        end
      end

    end
  end
end
