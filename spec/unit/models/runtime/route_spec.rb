require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Route, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe '#protocol' do
      let(:routing_api_client) { double('routing_api_client', router_group:) }
      let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
      end

      context 'when the route belongs to a domain with the "http" protocol' do
        let!(:domain) { SharedDomain.make }

        it 'returns "http"' do
          route = Route.new(domain:)
          expect(route.protocol).to eq('http')
        end
      end

      context 'when the route belongs to a domain with the "tcp" protocol' do
        let!(:tcp_domain) { SharedDomain.make(router_group_guid: 'guid') }

        it 'returns "tcp"' do
          route = Route.new(domain: tcp_domain, port: 6000)
          expect(route.protocol).to eq('tcp')
        end
      end
    end

    describe '#tcp?' do
      let(:routing_api_client) { double('routing_api_client', router_group:) }
      let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

      before do
        allow_any_instance_of(RouteValidator).to receive(:validate)
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
      end

      context 'when the route belongs to a shared domain' do
        context 'and that domain is a TCP domain' do
          let!(:tcp_domain) { SharedDomain.make(router_group_guid: 'guid') }

          context 'and the route has a port and it aint kubes' do
            let(:route) { Route.new(domain: tcp_domain, port: 6000) }

            it 'returns true' do
              # turn off kubernetes mode to surface actual tcp checking
              TestConfig.override(kubernetes: nil)
              expect(route.tcp?).to equal(true)
            end
          end

          context 'and the route does not have a port' do
            let(:route) { Route.new(domain: tcp_domain) }

            it 'returns false' do
              TestConfig.override(kubernetes: nil)
              expect(route.tcp?).to equal(false)
            end
          end

          context 'and that domain is not a TCP domain' do
            let!(:domain) { SharedDomain.make }

            context 'and the route has a port' do
              let(:route) { Route.new(domain: domain, port: 6000) }

              it 'returns false' do
                TestConfig.override(kubernetes: nil)
                expect(route.tcp?).to equal(false)
              end
            end

            context 'and the route does not have a port' do
              let(:route) { Route.new(domain: tcp_domain) }

              it 'returns false' do
                expect(route.tcp?).to equal(false)
              end
            end
          end
        end
      end

      context 'when the route belongs to a private domain' do
        let(:space) { Space.make }
        let!(:private_domain) { PrivateDomain.make(owning_organization: space.organization) }

        context 'and the route has a port' do
          let(:route) { Route.new(space: space, domain: private_domain, port: 6000) }

          it 'returns false' do
            expect(route.tcp?).to equal(false)
          end
        end

        context 'and the route does not have a port' do
          let(:route) { Route.new(space: space, domain: private_domain) }

          it 'returns false' do
            expect(route.tcp?).to equal(false)
          end
        end
      end
    end

    describe 'Associations' do
      it { is_expected.to have_associated :domain }
      it { is_expected.to have_associated :space, associated_instance: ->(route) { Space.make(organization: route.domain.owning_organization) } }
      it { is_expected.to have_associated :route_mappings, associated_instance: ->(route) { RouteMappingModel.make(app: AppModel.make(space: route.space), route: route) } }

      include_examples 'ignored_unique_constraint_violation_errors', Route.association_reflection(:shared_spaces), Route.db

      describe 'apps association' do
        let(:space) { Space.make }
        let(:process) { ProcessModelFactory.make(space:) }
        let(:route) { Route.make(space:) }

        it 'associates apps through route mappings' do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)

          expect(route.apps).to contain_exactly(process)
        end

        it 'does not associate non-web v2 apps' do
          non_web_process = ProcessModelFactory.make(type: 'other', space: space)

          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
          RouteMappingModel.make(app: non_web_process.app, route: route, process_type: non_web_process.type)

          expect(route.apps).to contain_exactly(process)
        end

        it 'returns a single app when an app is bound to multiple ports' do
          RouteMappingModel.make(app: process.app, route: route, app_port: 8080)
          RouteMappingModel.make(app: process.app, route: route, app_port: 9090)

          expect(route.apps.length).to eq(1)
        end
      end

      context 'when bound to a service instance' do
        let(:route) { Route.make }
        let(:service_instance) { ManagedServiceInstance.make(:routing, space: route.space) }
        let!(:route_binding) { RouteBinding.make(route:, service_instance:) }

        it 'has a service instance' do
          expect(route.service_instance).to eq service_instance
        end
      end

      context 'changing space' do
        context 'when the route sharing flag is enabled' do
          let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil) }

          it 'succeeds with no mapped apps' do
            route = Route.make(space: ProcessModelFactory.make.space, domain: SharedDomain.make)

            expect { route.space = Space.make }.not_to raise_error
          end

          it 'succeeds when there are apps mapped to it' do
            process = ProcessModelFactory.make
            route = Route.make(space: process.space, domain: SharedDomain.make)
            RouteMappingModel.make(app: process.app, route: route, process_type: process.type)

            expect { route.space = Space.make }.not_to raise_error
          end
        end

        context 'when the route sharing flag is disabled' do
          let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: false, error_message: nil) }

          it 'succeeds with no mapped apps' do
            route = Route.make(space: ProcessModelFactory.make.space, domain: SharedDomain.make)

            expect { route.space = Space.make }.not_to raise_error
          end

          it 'fails when changing the space when there are apps mapped to it' do
            process = ProcessModelFactory.make
            route = Route.make(space: process.space, domain: SharedDomain.make)
            RouteMappingModel.make(app: process.app, route: route, process_type: process.type)

            expect { route.space = Space.make }.to raise_error(CloudController::Errors::InvalidAppRelation)
          end
        end

        context 'with domain' do
          it 'succeeds if its a shared domain' do
            route = Route.make(domain: SharedDomain.make)
            expect { route.space = Space.make }.not_to raise_error
          end

          context 'private domain' do
            let(:org) { Organization.make }
            let(:domain) { PrivateDomain.make(owning_organization: org) }
            let(:route) { Route.make(domain: domain, space: Space.make(organization: org)) }

            it 'succeeds if in the same organization' do
              expect { route.space = Space.make(organization: org) }.not_to raise_error
            end

            context 'with a different organization' do
              it 'fails' do
                expect { route.space = Space.make }.to raise_error(Route::InvalidOrganizationRelation, /Organization cannot use domain/)
              end

              it 'succeeds if the organization shares the domain' do
                space = Space.make
                domain.add_shared_organization(space.organization)
                expect { route.space = space }.not_to raise_error
              end
            end
          end
        end
      end

      context 'creating context path routes across spaces' do
        let(:org1) { Organization.make(name: 'org1') }
        let(:space1a) { Space.make(name: 'space1a', organization: org1) }
        let(:space1b) { Space.make(name: 'space1b', organization: org1) }
        let(:domain) { PrivateDomain.make(name: 'tld.org', owning_organization: org1) }
        let(:org2) { Organization.make(name: 'org2') }
        let(:space2) { Space.make(name: 'space2', organization: org2) }
        let(:disable_context_route_sharing) { false }
        let(:host2) { 'host-' + SecureRandom.uuid }

        before do
          TestConfig.override(disable_private_domain_cross_space_context_path_route_sharing: disable_context_route_sharing)
        end

        context 'when the route matches host and domain' do
          let!(:first_route) { Route.make(host: 'host', domain: domain, space: space1a) }

          it 'cannot create the duplicate (no path) route in the same-org space' do
            expect do
              Route.make(host: 'host', domain: domain, space: space1b)
            end.to raise_error(Sequel::ValidationFailed, /host and domain_id and path unique/)
          end

          context 'when private domain context path route sharing is disabled' do
            let(:disable_context_route_sharing) { true }

            it 'cannot create a pathful route in the same-org space' do
              expect do
                Route.make(host: 'host', domain: domain, space: space1b, path: '/apples/kumquats')
              end.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
            end
          end

          context 'when private domain context path route sharing is NOT disabled' do
            it 'CAN create a pathful route in the same-org space' do
              r = Route.make(host: 'host', domain: domain, space: space1b, path: '/apples/kumquats')
              expect(r).to be_valid
            end
          end
        end

        context 'when the route does not match host and domain' do
          it 'can create a no-path route in the same-org space' do
            r = Route.make(host: 'host-' + SecureRandom.uuid, domain: domain, space: space1b)
            expect(r).to be_valid
          end
        end

        context 'the first route does have a path' do
          let!(:first_route) { Route.make(host: 'host', domain: domain, space: space1a, path: '/my-path') }

          context 'when private domain context path route sharing is NOT disabled' do
            it 'succeeds' do
              r = Route.make(host: 'host', domain: domain, space: space1b)
              expect(r).to be_valid
            end
          end

          context 'when private domain context path route sharing is disabled' do
            let(:disable_context_route_sharing) { true }

            it 'fails' do
              expect do
                Route.make(host: 'host', domain: domain, space: space1b)
              end.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
            end
          end
        end

        context 'when sharing private domains to other orgs' do
          let!(:first_route) { Route.make(host: 'host', domain: domain, space: space1a, path: '/mangos') }

          before do
            domain.add_shared_organization(org2)
          end

          context 'when private domain context path route sharing is NOT disabled' do
            it 'succeeds' do
              r = Route.make(host: 'host', domain: domain, space: space2, path: '/grapes')
              expect(r).to be_valid
            end
          end

          context 'when private domain context path route sharing is disabled' do
            let(:disable_context_route_sharing) { true }

            it 'fails' do
              expect do
                Route.make(host: 'host', domain: domain, space: space2, path: '/grapes')
              end.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
            end
          end
        end
      end

      context 'changing domain' do
        context 'when shared' do
          it "succeeds if it's the same domain" do
            domain = SharedDomain.make
            route = Route.make(domain:)
            route.domain = route.domain = domain
            expect { route.save }.not_to raise_error
          end

          it "fails if it's different" do
            route = Route.make(domain: SharedDomain.make)
            route.domain = SharedDomain.make
            expect(route).not_to be_valid
          end
        end

        context 'when private' do
          let(:space) { Space.make }
          let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

          it 'succeeds if it is the same domain' do
            route = Route.make(space:, domain:)
            route.domain = domain
            expect { route.save }.not_to raise_error
          end

          it 'fails if its a different domain' do
            route = Route.make(space:, domain:)
            route.domain = PrivateDomain.make(owning_organization: space.organization)
            expect(route).not_to be_valid
          end
        end
      end

      context 'deleting with route mappings' do
        before do
          TestConfig.override(
            kubernetes: {}
          )
        end

        it 'removes the associated route mappings' do
          route = Route.make
          app = AppModel.make(space: route.space)
          mapping1 = RouteMappingModel.make(route: route, app: app, process_type: 'thing')
          mapping2 = RouteMappingModel.make(route: route, app: app, process_type: 'other')

          route.destroy

          expect(mapping1).not_to exist
          expect(mapping2).not_to exist
        end
      end
    end

    describe 'Validations' do
      let!(:route) { Route.new }

      it { is_expected.to validate_presence :domain }
      it { is_expected.to validate_presence :space }
      it { is_expected.to validate_presence :host }

      it 'calls RouteValidator' do
        validator = double
        expect(RouteValidator).to receive(:new).and_return(validator)
        expect(validator).to receive(:validate)

        route.validate
      end

      context 'when routing api is disabled' do
        before do
          validator = double
          allow(RouteValidator).to receive(:new).and_return(validator)
          allow(validator).to receive(:validate).and_raise(RoutingApi::RoutingApiDisabled)
        end

        it 'adds routing_api_disabled to errors' do
          route.validate
          expect(route.errors.on(:routing_api)).to include :routing_api_disabled
        end
      end

      context 'when routing api raises UaaUnavailable error' do
        before do
          validator = double
          allow(RouteValidator).to receive(:new).and_return(validator)
          allow(validator).to receive(:validate).and_raise(RoutingApi::UaaUnavailable)
        end

        it 'adds uaa_unavailable to errors' do
          route.validate
          expect(route.errors.on(:routing_api)).to include :uaa_unavailable
        end
      end

      context 'when routing api raises RoutingApiUnavailable error' do
        before do
          validator = double
          allow(RouteValidator).to receive(:new).and_return(validator)
          allow(validator).to receive(:validate).and_raise(RoutingApi::RoutingApiUnavailable)
        end

        it 'adds routing_api_unavailable to errors' do
          route.validate
          expect(route.errors.on(:routing_api)).to include :routing_api_unavailable
        end
      end

      context 'when the requested route is a system hostname with a system domain' do
        let(:domain) { Domain.find(name: TestConfig.config[:system_domain]) }
        let(:space) { Space.make(organization: domain.owning_organization) }
        let(:host) { 'loggregator' }
        let(:route) { Route.new(domain:, space:, host:) }

        it 'is invalid' do
          expect(route).not_to be_valid
          expect(route.errors.on(:host)).to include :system_hostname_conflict
        end
      end

      context 'when a route with the same hostname and domain already exists' do
        let(:domain) { SharedDomain.make }
        let(:space) { Space.make }
        let(:host) { 'example' }

        context 'with a context path' do
          let(:path) { '/foo' }

          before do
            Route.make(domain:, space:, host:)
          end

          it 'is valid' do
            route_obj = Route.new(domain:, host:, space:, path:)
            expect(route_obj).to be_valid
          end

          context 'and a user attempts to create the route in another space' do
            let(:another_space) { Space.make }

            it 'is not valid' do
              route_obj = Route.new(domain: domain, space: another_space, host: host, path: path)
              expect(route_obj).not_to be_valid
              expect(route_obj.errors.on(%i[domain_id host])).to include :host_and_domain_taken_different_space
            end
          end

          context 'and the domain is a private domain' do
            let(:domain) { PrivateDomain.make }
            let(:space) { Space.make(organization: domain.owning_organization) }

            context 'and a user attempts to create the route in another space' do
              let(:another_space) { Space.make(organization: domain.owning_organization) }

              it 'is valid' do
                route_obj = Route.new(domain: domain, space: another_space, host: host, path: path)
                expect(route_obj).to be_valid
              end
            end
          end
        end

        context 'without a context path' do
          before do
            Route.make(domain: domain, space: space, host: host, path: '/bar')
          end

          context 'and a user attempts to create the route in another space' do
            let(:another_space) { Space.make }

            it 'is not valid' do
              route_obj = Route.new(domain: domain, space: another_space, host: host)
              expect(route_obj).not_to be_valid
              expect(route_obj.errors.on(%i[domain_id host])).to include :host_and_domain_taken_different_space
            end
          end
        end
      end

      context 'route ports' do
        let(:route) { Route.make }

        it 'validates that the port is greater than equal to 0' do
          route.port = -1
          expect(route).not_to be_valid
        end

        it 'validates that the port is less than 65536' do
          route.port = 65_536
          expect(route).not_to be_valid
        end

        it 'requires a host or port' do
          route.host = nil
          route.port = nil
          expect(route).not_to be_valid
        end

        it 'defaults the port to nil' do
          expect(route.port).to be_nil
        end

        context 'when port is specified' do
          let(:domain) { SharedDomain.make(router_group_guid: 'tcp-router-group') }
          let(:space_quota_definition) { SpaceQuotaDefinition.make }
          let(:space) { Space.make(space_quota_definition: space_quota_definition, organization: space_quota_definition.organization) }
          let(:routing_api_client) { double('routing_api_client', router_group:) }
          let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

          before do
            TestConfig.override(kubernetes: nil)
            allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
            validator = double
            allow(RouteValidator).to receive(:new).and_return(validator)
            allow(validator).to receive(:validate)
            Route.make(space: space, domain: domain, host: '', port: 1)
          end

          it 'does not validate uniqueness of host' do
            expect do
              Route.make(space: space, port: 10, host: '', domain: domain)
            end.not_to raise_error
          end

          it 'validates the uniqueness of the port' do
            new_route = Route.new(space: space, port: 1, host: '', domain: domain)
            expect(new_route).not_to be_valid
            expect(new_route.errors.on(%i[host domain_id port])).to include :unique
          end
        end
      end

      context 'unescaped paths' do
        it 'validates uniqueness' do
          r = Route.make(path: '/a')

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: r.path)
          end.to raise_error(Sequel::ValidationFailed)

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/b')
          end.not_to raise_error
        end

        it 'does not allow two blank paths with same host and domain' do
          r = Route.make

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id)
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'is case-insensitive' do
          r = Route.make(path: '/path')

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/PATH')
          end.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'escaped paths' do
        it 'validates uniqueness' do
          path = '/a%20path'
          r = Route.make(path:)

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: path)
          end.to raise_error(Sequel::ValidationFailed)

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/b%20path')
          end.not_to raise_error
        end

        it 'allows another route with same host and domain but no path' do
          path = '/a%20path'
          r = Route.make(path:)

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id)
          end.not_to raise_error
        end

        it 'allows a route with same host and domain with a path' do
          r = Route.make

          expect do
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/a/path')
          end.not_to raise_error
        end
      end

      context 'paths over 128 characters' do
        it 'raises exceeds valid length error' do
          path = '/path' * 100

          expect { Route.make(path:) }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'host' do
        let(:space) { Space.make }
        let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

        before do
          route.space = space
          route.domain = domain
        end

        it 'allows * to be the host name' do
          route.host = '*'
          expect(route).to be_valid
        end

        it 'does not allow * in the host name' do
          route.host = 'a*'
          expect(route).not_to be_valid
        end

        it 'does not allow . in the host name' do
          route.host = 'a.b'
          expect(route).not_to be_valid
        end

        it 'does not allow / in the host name' do
          route.host = 'a/b'
          expect(route).not_to be_valid
        end

        it 'does not allow a nil host' do
          expect do
            Route.make(space: space, domain: domain, host: nil)
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'allows an empty host' do
          Route.make(
            space: space,
            domain: domain,
            host: ''
          )
        end

        it 'does not allow a blank host' do
          expect do
            Route.make(
              space: space,
              domain: domain,
              host: ' '
            )
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow a long host' do
          expect do
            Route.make(
              space: space,
              domain: domain,
              host: 'f' * 63
            )
          end.not_to raise_error

          expect do
            Route.make(
              space: space,
              domain: domain,
              host: 'f' * 64
            )
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow a host which, along with the domain, exceeds the maximum length' do
          domain_200_chars = "#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 50}"
          domain_253_chars = "#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 50}.ff"
          domain = PrivateDomain.make(owning_organization: space.organization, name: domain_200_chars)
          domain_that_cannot_have_a_host = PrivateDomain.make(owning_organization: space.organization, name: domain_253_chars)

          valid_host = 'f' * 52
          invalid_host = 'f' * 53

          expect do
            Route.make(
              space: space,
              domain: domain,
              host: valid_host
            )
          end.not_to raise_error

          expect do
            Route.make(
              space: space,
              domain: domain_that_cannot_have_a_host,
              host: ''
            )
          end.not_to raise_error

          expect do
            Route.make(
              space: space,
              domain: domain,
              host: invalid_host
            )
          end.to raise_error(Sequel::ValidationFailed)
        end

        context 'shared domains' do
          it 'does not allow route to match existing domain' do
            SharedDomain.make name: 'bar.foo.com'
            expect do
              Route.make(
                space: space,
                domain: SharedDomain.make(name: 'foo.com'),
                host: 'bar'
              )
            end.to raise_error(Sequel::ValidationFailed, /domain_conflict/)
          end

          context 'when the host is missing' do
            it 'raises an informative error' do
              domain = SharedDomain.make name: 'bar.foo.com'
              expect do
                Route.make(
                  space: space,
                  domain: domain,
                  host: nil
                )
              end.to raise_error(Sequel::ValidationFailed, /host is required for shared-domains/)
            end
          end
        end
      end

      describe 'total allowed routes' do
        let(:space) { Space.make }
        let(:org_quota) { space.organization.quota_definition }
        let(:space_quota) { nil }

        before do
          space.space_quota_definition = space_quota
        end

        let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

        subject(:route) { Route.new(space: space, domain: domain, host: 'bar') }

        context 'for organization quotas' do
          context 'on create' do
            context 'when not exceeding total allowed routes' do
              before do
                org_quota.total_routes = 10
                org_quota.save
              end

              it 'does not have an error on organization' do
                subject.valid?
                expect(subject.errors.on(:organization)).to be_nil
              end
            end

            context 'when exceeding total allowed routes' do
              before do
                org_quota.total_routes = 0
                org_quota.total_reserved_route_ports = 0
                org_quota.save
              end

              it 'has the error on organization' do
                subject.valid?
                expect(subject.errors.on(:organization)).to include :total_routes_exceeded
              end
            end
          end

          context 'on update' do
            it 'does not validate the total routes limit if already existing' do
              subject.save

              expect(subject).to be_valid

              org_quota.total_routes = 0
              org_quota.total_reserved_route_ports = 0
              org_quota.save

              expect(subject).to be_valid
            end
          end
        end

        context 'for space quotas' do
          let(:space_quota) { SpaceQuotaDefinition.make(organization: subject.space.organization) }
          let(:tcp_domain) { SharedDomain.make(router_group_guid: 'guid') }

          context 'on create' do
            context 'when not exceeding total allowed routes' do
              before do
                space_quota.total_routes = 10
                space_quota.save
              end

              it 'does not have an error on the space' do
                subject.valid?
                expect(subject.errors.on(:space)).to be_nil
              end
            end

            context 'when exceeding total allowed routes' do
              before do
                space_quota.total_routes = 0
                space_quota.save
              end

              it 'has the error on the space' do
                subject.valid?
                expect(subject.errors.on(:space)).to include :total_routes_exceeded
              end
            end

            context 'when creating another tcp route' do
              subject(:another_route) { Route.new(space: space, domain: tcp_domain, host: '', port: 4444) }
              let!(:mock_router_api_client) do
                router_group = double('router_group', type: 'tcp', reservable_ports: [4444, 6000, 1234, 3455, 2222])
                routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
                allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client:))
              end

              before do
                space_quota.total_reserved_route_ports = 0
                space_quota.save
              end

              it 'is invalid' do
                expect(subject).not_to be_valid
                expect(subject.errors.on(:space)).to include :total_reserved_route_ports_exceeded
              end
            end
          end

          context 'on update' do
            it 'does not validate the total routes limit if already existing' do
              subject.save

              expect(subject).to be_valid

              space_quota.total_routes = 0
              space_quota.save

              expect(subject).to be_valid
            end
          end
        end

        describe 'quota evaluation order' do
          let(:space_quota) { SpaceQuotaDefinition.make(organization: subject.space.organization) }

          before do
            org_quota.total_routes = 0
            org_quota.total_reserved_route_ports = 0
            space_quota.total_routes = 10

            org_quota.save
            space_quota.save
          end

          it 'fails when the space quota is valid and the organization quota is exceeded' do
            subject.valid?
            expect(subject.errors.on(:space)).to be_nil
            expect(subject.errors.on(:organization)).to include :total_routes_exceeded
          end
        end
      end

      describe 'total reserved route ports' do
        let(:space_quota) { SpaceQuotaDefinition.make }
        let(:space) { Space.make(space_quota_definition: space_quota, organization: space_quota.organization) }
        let(:org_quota) { space.organization.quota_definition }
        let(:http_domain) { SharedDomain.make }
        let(:tcp_domain) { SharedDomain.make(router_group_guid: 'guid') }
        let(:validator) { double }

        let(:http_route) do
          Route.new(space: space,
                    domain: http_domain,
                    host: 'bar')
        end

        subject(:tcp_route) do
          Route.new(space: space,
                    domain: tcp_domain,
                    host: '',
                    port: 6000)
        end
        before do
          router_group = double('router_group', type: 'tcp', reservable_ports: [4444, 6000])
          routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
          allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
        end

        context 'on create' do
          context 'when the space does not have a space quota' do
            let(:space) { Space.make }

            before do
              TestConfig.override(kubernetes: nil)
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when not exceeding total allowed routes' do
            before do
              TestConfig.override(kubernetes: nil)
              org_quota.total_routes = 2
              org_quota.total_reserved_route_ports = 1
              org_quota.save
            end

            it 'is valid' do
              expect(subject).to be_valid
            end

            context 'when creating another http route' do
              subject(:another_route) { Route.new(space: space, domain: http_domain, host: 'foo') }

              before do
                http_route.save
              end

              it 'is valid' do
                expect(subject).to be_valid
              end
            end

            context 'when creating another tcp route' do
              subject(:another_route) { Route.new(space: space, domain: tcp_domain, host: '', port: 4444) }

              before do
                TestConfig.override(kubernetes: nil)
              end

              context 'when exceeding total_reserved_route_ports in org quota' do
                before do
                  tcp_route.save
                end

                it 'is invalid' do
                  expect(subject).not_to be_valid
                  expect(subject.errors.on(:organization)).to include :total_reserved_route_ports_exceeded
                end
              end

              context 'when exceeding total_reserved_route_ports in space quota' do
                before do
                  org_quota.total_routes = 10
                  org_quota.total_reserved_route_ports = 2
                  org_quota.save
                  space_quota.total_reserved_route_ports = 1
                  space_quota.save

                  tcp_route.save
                end

                it 'is invalid' do
                  expect(subject).not_to be_valid
                  expect(subject.errors.on(:space)).to include :total_reserved_route_ports_exceeded
                end
              end
            end
          end

          context 'when creating a route would exceed total routes' do
            before do
              org_quota.total_routes = 1
              org_quota.total_reserved_route_ports = 0
              org_quota.save
            end

            it 'has the error on organization' do
              expect(subject).not_to be_valid
              expect(subject.errors.on(:organization)).to include :total_reserved_route_ports_exceeded
            end

            context 'and the total reserved route ports is unlimited' do
              before do
                org_quota.total_routes = 0
                org_quota.total_reserved_route_ports = -1
                org_quota.save
              end

              it 'has the error on organization' do
                expect(subject).not_to be_valid
                expect(subject.errors.on(:organization)).to include :total_reserved_route_ports_exceeded
              end
            end

            context 'and the user does not specify a port' do
              subject(:route) { Route.new(space: space, domain: http_domain, host: 'bar') }

              before do
                org_quota.total_routes = 1
                org_quota.total_reserved_route_ports = 0
                org_quota.save
              end

              it 'is valid' do
                expect(subject).to be_valid
              end
            end
          end
        end

        context 'on update' do
          before do
            TestConfig.override(kubernetes: nil)
            org_quota.total_reserved_route_ports = 1
            org_quota.save
          end

          it 'does not validate the total routes limit if already existing' do
            expect(subject).to be_valid
            subject.save

            org_quota.total_reserved_route_ports = 0
            org_quota.save

            expect(subject).to be_valid
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :host, :domain_guid, :space_guid, :path, :service_instance_guid, :port, :options }
      it { is_expected.to import_attributes :host, :domain_guid, :space_guid, :app_guids, :path, :port, :options }
    end

    describe 'options normalization' do
      let(:space) { Space.make }
      let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

      context 'when hash_balance is provided as a float' do
        it 'stores hash_balance as a string in the database' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 1.5 }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['hash_balance']).to be_a(String)
          expect(parsed_options['hash_balance']).to eq('1.5')
        end
      end

      context 'when hash_balance is provided as an integer' do
        it 'stores hash_balance as a string in the database' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 2 }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['hash_balance']).to be_a(String)
          expect(parsed_options['hash_balance']).to eq('2.0')
        end
      end

      context 'when hash_balance is provided as a string' do
        it 'keeps hash_balance as a string in the database' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.25' }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['hash_balance']).to be_a(String)
          expect(parsed_options['hash_balance']).to eq('1.3')
        end
      end

      context 'when hash_balance is 0' do
        it 'stores hash_balance as a string "0" in the database' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 0 }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['hash_balance']).to be_a(String)
          expect(parsed_options['hash_balance']).to eq('0.0')
        end
      end

      context 'when options do not include hash_balance' do
        it 'does not add hash_balance to the options' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'round-robin' }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options).not_to have_key('hash_balance')
        end
      end

      context 'when options are nil' do
        it 'handles nil options gracefully' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: nil
          )

          route.reload
          expect(route.options).to be_nil
        end
      end
    end

    describe 'normalize_hash_balance_to_string' do
      let(:space) { Space.make }
      let(:domain) { PrivateDomain.make(owning_organization: space.organization) }
      let(:route) { Route.new(host: 'test', domain: domain, space: space) }

      context 'when hash_balance is provided as a float' do
        it 'converts it to a string' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: 1.5 })
          expect(result[:hash_balance]).to eq('1.5')
          expect(result[:hash_balance]).to be_a(String)
        end
      end

      context 'when hash_balance is provided as an integer' do
        it 'converts it to a string' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: 2 })
          expect(result[:hash_balance]).to eq('2')
          expect(result[:hash_balance]).to be_a(String)
        end
      end

      context 'when hash_balance is provided as 0' do
        it 'converts it to string "0"' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: 0 })
          expect(result[:hash_balance]).to eq('0')
          expect(result[:hash_balance]).to be_a(String)
        end
      end

      context 'when hash_balance is already a string' do
        it 'keeps it as a string' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: '1.25' })
          expect(result[:hash_balance]).to eq('1.25')
          expect(result[:hash_balance]).to be_a(String)
        end
      end

      context 'when hash_balance is provided with string key' do
        it 'converts it to a string with symbol key' do
          result = route.send(:normalize_hash_balance_to_string, { 'hash_balance' => 2.5 })
          expect(result[:hash_balance]).to eq('2.5')
          expect(result[:hash_balance]).to be_a(String)
        end
      end

      context 'when hash_balance is not present' do
        it 'returns the hash unchanged' do
          result = route.send(:normalize_hash_balance_to_string, { loadbalancing: 'hash', hash_header: 'X-User-ID' })
          expect(result[:loadbalancing]).to eq('hash')
          expect(result[:hash_header]).to eq('X-User-ID')
          expect(result).not_to have_key(:hash_balance)
        end
      end

      context 'when hash_balance is nil' do
        it 'does not convert nil to string' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: nil })
          expect(result[:hash_balance]).to be_nil
        end
      end

      context 'when hash_balance is an empty string' do
        it 'does not convert empty string' do
          result = route.send(:normalize_hash_balance_to_string, { hash_balance: '' })
          expect(result[:hash_balance]).to eq('')
        end
      end

      context 'when options is not a hash' do
        it 'returns the input unchanged' do
          result = route.send(:normalize_hash_balance_to_string, nil)
          expect(result).to be_nil
        end
      end

      context 'when options is an empty hash' do
        it 'returns an empty hash' do
          result = route.send(:normalize_hash_balance_to_string, {})
          expect(result).to eq({})
        end
      end

      context 'with complete options hash' do
        it 'normalizes hash_balance while preserving other options' do
          result = route.send(:normalize_hash_balance_to_string, {
                                loadbalancing: 'hash',
                                hash_header: 'X-User-ID',
                                hash_balance: 3.14159
                              })
          expect(result[:loadbalancing]).to eq('hash')
          expect(result[:hash_header]).to eq('X-User-ID')
          expect(result[:hash_balance]).to eq('3.14159')
          expect(result[:hash_balance]).to be_a(String)
        end
      end
    end

    describe 'hash options cleanup for non-hash loadbalancing' do
      let(:space) { Space.make }
      let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

      context 'when creating a route with hash loadbalancing' do
        it 'keeps hash_header and hash_balance' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['loadbalancing']).to eq('hash')
          expect(parsed_options['hash_header']).to eq('X-User-ID')
          expect(parsed_options['hash_balance']).to eq('1.5')
        end
      end

      context 'when updating a route from hash to round-robin' do
        it 'removes hash_header and hash_balance' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' }
          )

          route.update(options: { loadbalancing: 'round-robin' })
          route.reload

          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['loadbalancing']).to eq('round-robin')
          expect(parsed_options).not_to have_key('hash_header')
          expect(parsed_options).not_to have_key('hash_balance')
        end
      end

      context 'when updating a route from hash to least-connection' do
        it 'removes hash_header and hash_balance' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-Request-ID', hash_balance: '2.5' }
          )

          route.update(options: { loadbalancing: 'least-connection' })
          route.reload

          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['loadbalancing']).to eq('least-connection')
          expect(parsed_options).not_to have_key('hash_header')
          expect(parsed_options).not_to have_key('hash_balance')
        end
      end

      context 'when updating a route from round-robin to hash' do
        it 'keeps hash_header and hash_balance if provided' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'round-robin' }
          )

          route.update(options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' })
          route.reload

          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['loadbalancing']).to eq('hash')
          expect(parsed_options['hash_header']).to eq('X-User-ID')
          expect(parsed_options['hash_balance']).to eq('1.5')
        end
      end

      context 'when removing hash loadbalancing option' do
        it 'deletes hash_header and hash_balance when present' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' }
          )

          route.update(options: { loadbalancing: nil })
          route.reload

          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options).not_to have_key('hash_header')
          expect(parsed_options).not_to have_key('hash_balance')
        end
      end

      context 'when using string keys instead of symbols' do
        it 'still removes hash options for non-hash loadbalancing' do
          route = Route.make(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { 'loadbalancing' => 'round-robin', 'hash_header' => 'X-User-ID', 'hash_balance' => '1.5' }
          )

          route.reload
          parsed_options = Oj.load(route.options_without_serialization)
          expect(parsed_options['loadbalancing']).to eq('round-robin')
          expect(parsed_options).not_to have_key('hash_header')
          expect(parsed_options).not_to have_key('hash_balance')
        end
      end
    end

    describe 'route options validation' do
      let(:space) { Space.make }
      let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

      context 'when loadbalancing is hash' do
        context 'and hash_header is present' do
          it 'is valid' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'hash', hash_header: 'X-User-ID' }
            )

            expect(route).to be_valid
          end
        end

        context 'and hash_header is missing' do
          it 'is invalid and adds an error' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'hash' }
            )

            expect(route).not_to be_valid
            expect(route.errors[:route]).to include :hash_header_missing
          end
        end

        context 'and hash_header is blank string' do
          it 'is invalid and adds an error' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'hash', hash_header: '' }
            )

            expect(route).not_to be_valid
            expect(route.errors[:route]).to include :hash_header_missing
          end
        end

        context 'and hash_header and hash_balance are both present' do
          it 'is valid' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '1.5' }
            )

            expect(route).to be_valid
          end
        end
      end

      context 'when loadbalancing is round-robin' do
        it 'is valid' do
          route = Route.new(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'round-robin' }
          )

          expect(route).to be_valid
        end
      end

      context 'when loadbalancing is least-connection' do
        it 'is valid' do
          route = Route.new(
            host: 'test-route',
            domain: domain,
            space: space,
            options: { loadbalancing: 'least-connection' }
          )

          expect(route).to be_valid
        end
      end

      context 'when options are nil' do
        it 'is valid' do
          route = Route.new(
            host: 'test-route',
            domain: domain,
            space: space,
            options: nil
          )

          expect(route).to be_valid
        end
      end

      context 'when options are empty hash' do
        it 'is valid' do
          route = Route.new(
            host: 'test-route',
            domain: domain,
            space: space,
            options: {}
          )

          expect(route).to be_valid
        end
      end

      context 'when updating an existing route' do
        context 'changing to hash loadbalancing without hash_header' do
          it 'is invalid' do
            route = Route.make(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'round-robin' }
            )

            route.options = { loadbalancing: 'hash' }

            expect(route).not_to be_valid
            expect(route.errors[:route]).to include :hash_header_missing
          end
        end

        context 'changing to hash loadbalancing with hash_header' do
          it 'is valid' do
            route = Route.make(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { loadbalancing: 'round-robin' }
            )

            route.options = { loadbalancing: 'hash', hash_header: 'X-Request-ID' }

            expect(route).to be_valid
          end
        end
      end

      context 'when options use string keys instead of symbols' do
        context 'and hash_header is present' do
          it 'is valid' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID' }
            )

            expect(route).to be_valid
          end
        end

        context 'and hash_header is missing' do
          it 'is invalid and adds an error' do
            route = Route.new(
              host: 'test-route',
              domain: domain,
              space: space,
              options: { 'loadbalancing' => 'hash' }
            )

            expect(route).not_to be_valid
            expect(route.errors[:route]).to include :hash_header_missing
          end
        end
      end
    end

    describe 'instance methods' do
      let(:space) { Space.make }

      let(:domain) do
        PrivateDomain.make(
          owning_organization: space.organization
        )
      end

      describe '#fqdn' do
        context 'for a non-nil path' do
          it 'returns the fqdn for the route' do
            r = Route.make(
              host: 'www',
              domain: domain,
              space: space,
              path: '/path'
            )
            expect(r.fqdn).to eq("www.#{domain.name}")
          end
        end

        context 'for a nil path' do
          context 'for a non-nil host' do
            it 'returns the fqdn for the route' do
              r = Route.make(
                host: 'www',
                domain: domain,
                space: space
              )
              expect(r.fqdn).to eq("www.#{domain.name}")
            end
          end

          context 'for a nil host' do
            it 'returns the fqdn for the route' do
              r = Route.make(
                host: '',
                domain: domain,
                space: space
              )
              expect(r.fqdn).to eq(domain.name)
            end
          end
        end
      end

      describe 'route_service_url' do
        context 'with a route_binding' do
          let(:route_binding) { RouteBinding.make }
          let(:route) { route_binding.route }

          it 'returns the route_service_url associated with the binding' do
            expect(route.route_service_url).to eq route_binding.route_service_url
          end
        end

        context 'without a route_binding' do
          let(:route) { Route.make }

          it 'returns nil' do
            expect(route.route_service_url).to be_nil
          end
        end
      end

      describe '#uri' do
        context 'for a non-nil path' do
          it 'returns the fqdn with path' do
            r = Route.make(
              host: 'www',
              domain: domain,
              space: space,
              path: '/path'
            )
            expect(r.uri).to eq("www.#{domain.name}/path")
          end

          context 'that has a port' do
            it 'returns the fqdn with the path and port' do
              r = Route.make(
                host: 'www',
                domain: domain,
                space: space,
                path: '/path'
              )
              r.port = 1041
              expect(r.uri).to eq("www.#{domain.name}/path:1041")
            end
          end
        end

        context 'for a nil path' do
          it 'returns the fqdn' do
            r = Route.make(
              host: 'www',
              domain: domain,
              space: space
            )
            expect(r.uri).to eq("www.#{domain.name}")
          end
        end
      end

      describe '#as_summary_json' do
        it 'returns a hash containing the route id, host, and domain details' do
          r = Route.make(
            host: 'www',
            domain: domain,
            space: space
          )
          expect(r.as_summary_json).to eq(
            {
              guid: r.guid,
              host: r.host,
              port: r.port,
              path: r.path,
              domain: {
                guid: r.domain.guid,
                name: r.domain.name
              }
            }
          )
        end
      end

      describe '#in_suspended_org?' do
        let(:space) { Space.make }

        subject(:route) { Route.new(space:) }

        context 'when in a suspended organization' do
          before { allow(space).to receive(:in_suspended_org?).and_return(true) }

          it 'is true' do
            expect(route).to be_in_suspended_org
          end
        end

        context 'when in an unsuspended organization' do
          before { allow(space).to receive(:in_suspended_org?).and_return(false) }

          it 'is false' do
            expect(route).not_to be_in_suspended_org
          end
        end
      end
    end

    describe 'relations' do
      let(:org) { Organization.make }
      let(:space_a) { Space.make(organization: org) }
      let(:domain_a) { PrivateDomain.make(owning_organization: org) }

      let(:space_b) { Space.make(organization: org) }
      let(:domain_b) { PrivateDomain.make(owning_organization: org) }

      it 'does not allow creation of a empty host on a shared domain' do
        shared_domain = SharedDomain.make

        expect do
          Route.make(
            host: '',
            space: space_a,
            domain: shared_domain
          )
        end.to raise_error Sequel::ValidationFailed
      end
    end

    describe '#destroy' do
      let(:route) { Route.make }

      it 'marks the apps routes as changed and sends an update to diego' do
        fake_route_handler_app1 = instance_double(ProcessRouteHandler)
        fake_route_handler_app2 = instance_double(ProcessRouteHandler)

        space = Space.make
        process1 = ProcessModelFactory.make(space: space, state: 'STARTED', diego: false)
        process2 = ProcessModelFactory.make(space: space, state: 'STARTED', diego: false)

        route = Route.make(space:)
        RouteMappingModel.make(app: process1.app, route: route, process_type: process1.type)
        RouteMappingModel.make(app: process2.app, route: route, process_type: process2.type)
        route.reload

        process1 = route.apps[0]
        process2 = route.apps[1]

        allow(ProcessRouteHandler).to receive(:new).with(process1).and_return(fake_route_handler_app1)
        allow(ProcessRouteHandler).to receive(:new).with(process2).and_return(fake_route_handler_app2)

        expect(fake_route_handler_app1).to receive(:notify_backend_of_route_update)
        expect(fake_route_handler_app2).to receive(:notify_backend_of_route_update)

        route.destroy
      end

      context 'with route bindings' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }
        let(:process) { ProcessModelFactory.make(space: route.space, diego: true) }

        before do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
          stub_unbind(route_binding)
        end

        it 'deletes any associated route_bindings' do
          route_binding_guid = route_binding.guid

          route.destroy
          expect(RouteBinding.find(guid: route_binding_guid)).to be_nil
          expect(process.reload.routes).to be_empty
        end

        context 'when deleting the route binding errors' do
          before do
            stub_unbind(route_binding, status: 500)
          end

          it 'does not delete the route or associated data and raises an error' do
            route_binding_guid = route_binding.guid

            expect do
              route.destroy
            end.to raise_error VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse
            expect(RouteBinding.find(guid: route_binding_guid)).to eq route_binding
            expect(process.reload.routes[0]).to eq route
          end
        end

        context 'when route_binding is deleted externally before destroy' do
          before do
            allow_any_instance_of(ServiceKeyDelete).to receive(:delete_service_binding).and_wrap_original do |original_method, *args|
              service_binding = args.first
              service_binding.destroy
              original_method.call(*args)
            end
          end

          it 'does not raise a Sequel::NoExistingObject error' do
            route_binding = RouteBinding.make
            route = route_binding.route
            stub_unbind(route_binding)
            expect { route.destroy }.not_to raise_error
          end
        end
      end
    end

    def assert_valid_path(path)
      r = Route.make(path:)
      expect(r).to be_valid
    end

    def assert_invalid_path(path)
      expect do
        Route.make(path:)
      end.to raise_error(Sequel::ValidationFailed)
    end

    context 'decoded paths' do
      it 'does not allow a path of just slash' do
        assert_invalid_path('/')
      end

      it 'allows a blank path' do
        assert_valid_path('') # kinda weird but it's like not having a path
      end

      it 'does not allow path that does not start with a slash' do
        assert_invalid_path('bar')
      end

      it 'allows a path starting with a slash' do
        assert_valid_path('/foo')
      end

      it 'allows a multi-part path' do
        assert_valid_path('/foo/bar')
      end

      it 'allows a multi-part path ending with a slash' do
        assert_valid_path('/foo/bar/')
      end

      it 'allows equal sign as part of the path' do
        assert_valid_path('/foo=bar')
      end

      it 'does not allow question mark' do
        assert_invalid_path('/foo?a=b')
      end

      it 'does not allow trailing question mark' do
        assert_invalid_path('/foo?')
      end

      it 'does not allow non-ASCII characters in the path' do
        assert_invalid_path('/barΩ')
      end
    end

    context 'encoded paths' do
      it 'does not allow a path of just slash' do
        assert_invalid_path('%2F')
      end

      it 'allows a path of just slash' do
        assert_invalid_path('%2F')
      end

      it 'does not allow a path that does not start with slash' do
        assert_invalid_path('%20space')
      end

      it 'allows a path that contains ?' do
        assert_valid_path('/%3F')
      end

      it 'allows a path that begins with an escaped slash' do
        assert_invalid_path('%2Fpath')
      end

      it 'allows all other escaped chars in a proper url' do
        assert_valid_path('/a%20space')
      end
    end

    describe '#internal?' do
      before do
        TestConfig.override(
          kubernetes: {}
        )
      end

      let(:internal_domain) { SharedDomain.make(name: 'apps.internal', internal: true) }
      let(:internal_route) { Route.make(host: 'meow', domain: internal_domain) }
      let(:external_private_route) { Route.make }

      context 'when the route has an internal domain' do
        it 'is true' do
          expect(internal_route.internal?).to be(true)
        end
      end

      context 'when the route has a non-internal domain' do
        it 'is false' do
          expect(external_private_route.internal?).to be(false)
        end
      end
    end

    describe '#wildcard_host?' do
      let!(:route) { Route.make(host:) }

      context 'when the host is *' do
        let(:host) { '*' }

        it 'returns true' do
          expect(route.wildcard_host?).to be(true)
        end
      end

      context 'when the host is not *' do
        let(:host) { 'meow' }

        it 'returns false' do
          expect(route.wildcard_host?).to be(false)
        end
      end
    end

    describe 'app spaces and route shared spaces' do
      let!(:domain) { SharedDomain.make }

      context 'when app and route space not shared' do
        let!(:app) { AppModel.make }
        let!(:route) { Route.make(host: 'potato', domain: domain, path: '/some-path') }

        it 'no space match and not shared and returns false' do
          expect(route.available_in_space?(app.space)).to be(false)
        end

        it 'match space and returns true' do
          route.space = app.space
          expect(route.available_in_space?(app.space)).to be(true)
        end
      end

      context 'when app and route space shared' do
        let!(:app) { AppModel.make }
        let!(:route_share) { RouteShare.new }
        let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
        let!(:route) { Route.make(host: 'potato', domain: domain, path: '/some-path') }
        let!(:shared_route) { route_share.create(route, [app.space], user_audit_info) }

        it 'shared space match and returns true' do
          expect(route.available_in_space?(app.space)).to be(true)
        end
      end
    end
  end
end
