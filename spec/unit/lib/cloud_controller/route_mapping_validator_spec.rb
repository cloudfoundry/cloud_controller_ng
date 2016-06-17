require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteMappingValidator do
    let(:app) { AppFactory.make }
    let(:tcp_domain) { SharedDomain.make(router_group_guid: 'router-group-guid') }
    let(:domain) { SharedDomain.make }
    let(:space_quota) { SpaceQuotaDefinition.make(organization: app.organization) }
    let(:space) { Space.make(space_quota_definition: space_quota, organization: app.organization) }
    let(:http_route) { Route.make(domain: domain, host: 'test', space: space) }
    let(:tcp_route) { Route.make(domain: tcp_domain, port: 9090, host: '', space: space) }
    before do
      allow_any_instance_of(RouteValidator).to receive(:validate)
    end

    context 'when app does not exist' do
      it 'raises an error' do
        validator = RouteMappingValidator.new(http_route, nil)
        expect { validator.validate }.to raise_error RouteMappingValidator::AppInvalidError
      end
    end

    context 'when route does not exist' do
      it 'raises an error' do
        validator = RouteMappingValidator.new(nil, app)
        expect { validator.validate }.to raise_error RouteMappingValidator::RouteInvalidError
      end
    end

    context 'when routing api is enabled' do
      before do
        TestConfig.override(routing_api: { url: 'routing-api.com' })
      end

      it 'does not raise an error when route is tcp route' do
        validator = RouteMappingValidator.new(tcp_route, app)
        expect { validator.validate }.to_not raise_error
      end

      it 'does not raise an error when route is http route' do
        validator = RouteMappingValidator.new(http_route, app)
        expect { validator.validate }.to_not raise_error
      end
    end

    context 'when routing api is disabled' do
      before do
        TestConfig.override(routing_api: nil)
      end

      it 'raises an error when route is tcp route' do
        validator = RouteMappingValidator.new(tcp_route, app)
        expect { validator.validate }.to raise_error RouteMappingValidator::TcpRoutingDisabledError
      end

      it 'does not raise an error when route is http route' do
        validator = RouteMappingValidator.new(http_route, app)
        expect { validator.validate }.to_not raise_error
      end
    end
  end
end
