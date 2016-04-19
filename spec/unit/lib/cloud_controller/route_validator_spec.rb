require 'spec_helper'

module VCAP::CloudController
  describe RouteValidator do
    let(:route) { Route.new 'port' => port, 'host' => host, 'path' => path }
    let(:validator) { RouteValidator.new(domain_guid, route) }
    let(:routing_api_client) { double('routing_api', router_group: router_group) }
    let(:router_group) { double(:router_group, type: router_group_type, guid: router_group_guid, reservable_ports: [3, 4, 5, 8080]) }
    let(:router_group_type) { 'tcp' }
    let(:router_group_guid) { 'router-group-guid' }
    let(:domain_guid) { domain.guid }
    let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }
    let(:port) { 8080 }
    let(:host) { '' }
    let(:path) { '' }

    before do
      allow(CloudController::DependencyLocator).to receive(:instance).
        and_return(double('routing_api_double',
                          routing_api_client: routing_api_client))
    end

    context 'when non-existent domain is specified' do
      let(:domain_guid) { 'non-existent-domain' }

      it 'raises a DomainInvalid error' do
        expect { validator.validate }.
          to raise_error(RouteValidator::DomainInvalid, 'Domain with guid non-existent-domain does not exist')
      end
    end

    context 'when creating a route with a null port value' do
      let(:port) { nil }

      context 'with a tcp domain' do
        let(:domain) { SharedDomain.make(router_group_guid: router_group_guid) }

        it 'raises a RouteInvalid error' do
          expect { validator.validate }.
            to raise_error(RouteValidator::RouteInvalid, 'For TCP routes you must specify a port or request a random one.')
        end
      end
    end

    context 'when creating a route with a port value that is not null' do
      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'raises a RouteInvalid error' do
          expect { validator.validate }.
            to raise_error(RouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end

      context 'with a domain with a router_group_guid and type tcp' do
        it 'does not raise an error' do
          expect { validator.validate }.not_to raise_error
        end

        context 'with port that is not part of the reservable port range' do
          let(:port) { 1023 }

          it 'raises a RouteInvalid error' do
            err_msg = 'The requested port is not available for reservation. Try a different port or request a random one be generated for you.'
            expect { validator.validate }.
              to raise_error(RouteValidator::RouteInvalid, err_msg)
          end
        end

        context 'host is included in request' do
          let(:host) { 'abc' }
          it 'raises a RouteInvalid error' do
            expect { validator.validate }.
              to raise_error(RouteValidator::RouteInvalid, 'Host and path are not supported, as domain belongs to a TCP router group.')
          end
        end

        context 'host is empty in request' do
          let(:host) { '' }
          it 'does not raise an error' do
            expect { validator.validate }.not_to raise_error
          end
        end

        context 'path is included in request' do
          let(:path) { '/fake/path' }
          it 'raises a RouteInvalid error' do
            expect { validator.validate }.
              to raise_error(RouteValidator::RouteInvalid, 'Host and path are not supported, as domain belongs to a TCP router group.')
          end
        end

        context 'path is empty in request' do
          let(:path) { '' }
          it 'does not raise an error' do
            expect { validator.validate }.not_to raise_error
          end
        end

        context 'when port is already taken in the same router group' do
          before do
            domain_in_same_router_group = SharedDomain.make(router_group_guid: router_group_guid)
            Route.make(domain: domain_in_same_router_group, port: port)
          end

          it 'raises a RoutePortTaken error' do
            error_message = "Port #{port} is not available on this domain's router group. " \
                'Try a different port, request an random port, or ' \
                'use a domain of a different router group.'

            expect { validator.validate }.
              to raise_error(RouteValidator::RoutePortTaken, error_message)
          end
        end

        context 'when port is already taken in a different router group' do
          before do
            domain_in_different_router_group = SharedDomain.make(router_group_guid: 'different-router-group')
            Route.make(domain: domain_in_different_router_group, port: port)
          end

          it 'does not raise an error' do
            expect { validator.validate }.not_to raise_error
          end
        end
      end

      context 'with a domain without a router_group_guid' do
        let(:domain) { SharedDomain.make(router_group_guid: nil) }

        it 'rejects the request with a RouteInvalid error' do
          expect { validator.validate }.
            to raise_error(RouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end

      context 'with a domain with a router_group_guid of type other than tcp' do
        let(:router_group_type) { 'http' }

        it 'rejects the request with a RouteInvalid error' do
          expect { validator.validate }.
            to raise_error(RouteValidator::RouteInvalid, 'Port is supported for domains of TCP router groups only.')
        end
      end
    end

    context 'when the routing api is disabled' do
      let(:validator) { RouteValidator.new(domain_guid, route) }

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
