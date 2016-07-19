require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteValidator do
    let(:space_quota) { SpaceQuotaDefinition.make }
    let(:space) { Space.make(space_quota_definition: space_quota, organization: space_quota.organization) }
    let(:route) { Route.new port: port, host: host, path: path, domain: domain, space: space }
    let(:validator) { RouteValidator.new(route) }
    let(:routing_api_client) { double('routing_api', router_group: router_group, enabled?: true) }
    let(:router_group) { double(:router_group, type: router_group_type, guid: router_group_guid, reservable_ports: [3, 4, 5, 8080]) }
    let(:router_group_type) { 'tcp' }
    let(:router_group_guid) { 'router-group-guid' }
    let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }
    let(:port) { 8080 }
    let(:host) { '' }
    let(:path) { '' }

    before do
      allow(CloudController::DependencyLocator).to receive(:instance).
        and_return(double('routing_api_double',
                          routing_api_client: routing_api_client))
    end

    context 'when creating a route with a null port value' do
      let(:port) { nil }

      context 'with a tcp domain' do
        let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }

        it 'adds port_required error to the route' do
          validator.validate
          expect(route.errors.on(:port)).to include(:port_required)
        end
      end
    end

    context 'when creating a route with a port value that is not null' do
      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'adds port_unsupported error to the route' do
          validator.validate
          expect(route.errors.on(:port)).to include(:port_unsupported)
        end
      end

      context 'with a domain with a router_group_guid and type tcp' do
        it 'does not add the error' do
          validator.validate
          expect(route.errors).to be_empty
        end

        context 'with port that is not part of the reservable port range' do
          let(:port) { 1023 }

          it 'adds port_unavailable error to the route' do
            validator.validate
            expect(route.errors.on(:port)).to include(:port_unavailable)
          end
        end

        context 'host is included in request' do
          let(:host) { 'abc' }

          it 'adds host_and_path_domain_tcp to route model errors' do
            validator.validate
            expect(route.errors.on(:host)).to include(:host_and_path_domain_tcp)
          end
        end

        context 'host is empty in request' do
          let(:host) { '' }
          it 'does not add errors' do
            validator.validate
            expect(route.errors).to be_empty
          end
        end

        context 'path is included in request' do
          let(:path) { '/fake/path' }

          it 'adds host_and_path_domain_tcp to route model errors' do
            validator.validate
            expect(route.errors.on(:host)).to include(:host_and_path_domain_tcp)
          end
        end

        context 'path is empty in request' do
          let(:path) { '' }
          it 'does not add an error to the route' do
            validator.validate
            expect(route.errors).to be_empty
          end
        end

        context 'when port is already taken in the same router group' do
          context 'in same domain' do
            let(:another_route) { Route.new(domain: domain, port: port, space: space) }

            before do
              route.save
            end

            it 'adds a route_port_taken error to the route' do
              RouteValidator.new(another_route).validate
              expect(another_route.errors.on(:port)).to include(:port_taken)
            end
          end

          context 'in different domain' do
            let(:another_domain) { SharedDomain.make(router_group_guid: router_group_guid) }
            let(:another_route) { Route.new(domain: another_domain, port: port, space: Space.make) }

            before do
              route.save
            end

            it 'adds a route_port_taken error to the route' do
              RouteValidator.new(another_route).validate
              expect(another_route.errors.on(:port)).to include(:port_taken)
            end
          end
        end

        context 'when port is already taken in a different router group' do
          let(:domain_in_different_router_group) { SharedDomain.make(router_group_guid: 'different-router-group') }
          let(:another_route) { Route.new(domain: domain_in_different_router_group, port: port, space: Space.make) }

          before do
            route.save
          end

          it 'does not add an error to the route' do
            RouteValidator.new(another_route).validate
            expect(another_route.errors).to be_empty
          end
        end
      end

      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'adds port_unsupported error to the route model' do
          validator.validate
          expect(route.errors.on(:port)).to include(:port_unsupported)
        end
      end

      context 'with a domain with a router_group_guid of type other than tcp' do
        let(:router_group_type) { 'http' }

        it 'adds port_unsupported error to the route' do
          # expect { validator.validate }.
          #   to raise_error(RouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
          validator.validate
          expect(route.errors.on(:port)).to include(:port_unsupported)
        end
      end
    end

    context 'when the routing api is disabled' do
      let(:validator) { RouteValidator.new(route) }

      before do
        allow(CloudController::DependencyLocator).to receive(:instance).
          and_return(double('routing_api_double',
                            routing_api_client: RoutingApi::DisabledClient.new))
      end

      it 'raises a routing api disabled error' do
        expect { validator.validate }.
          to raise_error(RoutingApi::RoutingApiDisabled)
      end
    end

    context 'when the routing api client does not know about router group' do
      before do
        allow(routing_api_client).to receive(:router_group).and_return(nil)
      end

      it 'add router_group error' do
        validator.validate
        expect(route.errors.on(:router_group)).to include('router-group-guid')
      end
    end

    context 'when the routing api client raises a UaaUnavailable error' do
      before do
        allow(routing_api_client).to receive(:router_group).
          and_raise(RoutingApi::UaaUnavailable)
      end

      it 'does not rescue the exception' do
        expect { validator.validate }.
          to raise_error(RoutingApi::UaaUnavailable)
      end
    end

    context 'when the routing api client raises a RoutingApiUnavailable error' do
      before do
        allow(routing_api_client).to receive(:router_group).
          and_raise(RoutingApi::RoutingApiUnavailable)
      end

      it 'does not rescue the exception' do
        expect { validator.validate }.
          to raise_error(RoutingApi::RoutingApiUnavailable)
      end
    end
  end
end
