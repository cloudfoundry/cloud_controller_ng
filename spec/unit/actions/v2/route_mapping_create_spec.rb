require 'spec_helper'

module VCAP::CloudController
  module V2
    RSpec.describe RouteMappingCreate do
      subject(:action) { described_class.new(user, user_email, route, process) }

      let(:user) { User.make }
      let(:user_email) { 'tim@example.com' }

      describe '#add' do
        let(:route) { Route.make }
        let(:process) { AppFactory.make(space: route.space, diego: true, ports: [4443]) }
        let(:request_attrs) { {} }

        it 'maps the route' do
          expect {
            route_mapping = action.add(request_attrs)
            expect(route_mapping.route.guid).to eq(route.guid)
            expect(route_mapping.process.guid).to eq(process.guid)
          }.to change { RouteMappingModel.count }.by(1)
        end

        describe 'app port request' do
          context 'when the user requested an app port' do
            let(:request_attrs) { { 'app_port' => 4443 } }

            it 'requests that port' do
              route_mapping = action.add(request_attrs)
              expect(route_mapping.app_port).to eq(4443)
            end

            context 'running on dea backend' do
              let(:process) { AppFactory.make(space: route.space, diego: false) }

              it 'raises AppPortNotSupportedError' do
                expect { action.add(request_attrs) }.to raise_error(RouteMappingCreate::AppPortNotSupportedError)
              end
            end
          end

          context 'when the user did not request an app port' do
            let(:request_attrs) { {} }

            context 'when the process has ports' do
              let(:process) { AppFactory.make(space: route.space, diego: true, ports: [1234, 5678]) }

              it 'requests the first port from the process port list' do
                route_mapping = action.add(request_attrs)
                expect(route_mapping.app_port).to eq(1234)
              end
            end

            context 'when the process has no ports' do
              let(:process) { AppFactory.make(space: route.space, diego: true, ports: nil) }

              it 'uses the default port' do
                route_mapping = action.add(request_attrs)
                expect(route_mapping.app_port).to eq(App::DEFAULT_HTTP_PORT)
              end
            end
          end
        end

        context 'when the route is bound to a route service' do
          let(:route_binding) { RouteBinding.make }
          let(:route) { route_binding.route }

          it 'maps the route' do
            expect {
              route_mapping = action.add(request_attrs)
              expect(route_mapping.route.guid).to eq(route.guid)
              expect(route_mapping.process.guid).to eq(process.guid)
            }.to change { RouteMappingModel.count }.by(1)
          end

          context 'running on dea backend' do
            let(:process) { AppFactory.make(space: route.space, diego: false) }

            it 'raises RouteServiceNotSupportedError' do
              expect { action.add(request_attrs) }.to raise_error(RouteMappingCreate::RouteServiceNotSupportedError)
            end
          end
        end

        context 'when the route has a tcp domain' do
          let(:tcp_domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
          let(:route) { Route.make(domain: tcp_domain, port: 5155) }

          before do
            allow_any_instance_of(RouteValidator).to receive(:validate)
          end

          it 'maps the route' do
            expect {
              route_mapping = action.add(request_attrs)
              expect(route_mapping.route.guid).to eq(route.guid)
              expect(route_mapping.process.guid).to eq(process.guid)
            }.to change { RouteMappingModel.count }.by(1)
          end

          context 'when the routing api is disabled' do
            before do
              TestConfig.config[:routing_api] = nil
            end

            it 'raises TcpRoutingDisabledError' do
              expect { action.add(request_attrs) }.to raise_error(RouteMappingCreate::TcpRoutingDisabledError)
            end
          end
        end
      end
    end
  end
end
