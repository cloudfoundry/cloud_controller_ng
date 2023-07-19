require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Route, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe '#protocol' do
      let(:routing_api_client) { double('routing_api_client', router_group: router_group) }
      let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
      end

      context 'when the route belongs to a domain with the "http" protocol' do
        let!(:domain) { SharedDomain.make }
        it 'returns "http"' do
          route = Route.new(domain: domain)
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
      let(:routing_api_client) { double('routing_api_client', router_group: router_group) }
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

      describe 'apps association' do
        let(:space) { Space.make }
        let(:process) { ProcessModelFactory.make(space: space) }
        let(:route) { Route.make(space: space) }

        it 'associates apps through route mappings' do
          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)

          expect(route.apps).to match_array([process])
        end

        it 'does not associate non-web v2 apps' do
          non_web_process = ProcessModelFactory.make(type: 'other', space: space)

          RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
          RouteMappingModel.make(app: non_web_process.app, route: route, process_type: non_web_process.type)

          expect(route.apps).to match_array([process])
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
        let!(:route_binding) { RouteBinding.make(route: route, service_instance: service_instance) }

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
                expect { route.space = space }.to_not raise_error
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
            expect {
              Route.make(host: 'host', domain: domain, space: space1b)
            }.to raise_error(Sequel::ValidationFailed, /host and domain_id and path unique/)
          end

          context 'when private domain context path route sharing is disabled' do
            let(:disable_context_route_sharing) { true }

            it 'cannot create a pathful route in the same-org space' do
              expect {
                Route.make(host: 'host', domain: domain, space: space1b, path: '/apples/kumquats')
              }.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
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
              expect {
                Route.make(host: 'host', domain: domain, space: space1b)
              }.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
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
              expect {
                Route.make(host: 'host', domain: domain, space: space2, path: '/grapes')
              }.to raise_error(Sequel::ValidationFailed, /domain_id and host host_and_domain_taken_different_space/)
            end
          end
        end
      end

      context 'changing domain' do
        context 'when shared' do
          it "succeeds if it's the same domain" do
            domain = SharedDomain.make
            route = Route.make(domain: domain)
            route.domain = route.domain = domain
            expect { route.save }.not_to raise_error
          end

          it "fails if it's different" do
            route = Route.make(domain: SharedDomain.make)
            route.domain = SharedDomain.make
            expect(route.valid?).to be_falsey
          end
        end

        context 'when private' do
          let(:space) { Space.make }
          let(:domain) { PrivateDomain.make(owning_organization: space.organization) }
          it 'succeeds if it is the same domain' do
            route = Route.make(space: space, domain: domain)
            route.domain = domain
            expect { route.save }.not_to raise_error
          end

          it 'fails if its a different domain' do
            route = Route.make(space: space, domain: domain)
            route.domain = PrivateDomain.make(owning_organization: space.organization)
            expect(route.valid?).to be_falsey
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

          expect(mapping1.exists?).to be_falsey
          expect(mapping2.exists?).to be_falsey
        end
      end
    end

    describe 'Validations' do
      let!(:route) { Route.new }

      it { is_expected.to validate_presence :domain }
      it { is_expected.to validate_presence :space }
      it { is_expected.to validate_presence :host }

      it 'should call RouteValidator' do
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

        it 'should add routing_api_disabled to errors' do
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

        it 'should add uaa_unavailable to errors' do
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

        it 'should add routing_api_unavailable to errors' do
          route.validate
          expect(route.errors.on(:routing_api)).to include :routing_api_unavailable
        end
      end

      context 'when the requested route is a system hostname with a system domain' do
        let(:domain) { Domain.find(name: TestConfig.config[:system_domain]) }
        let(:space) { Space.make(organization: domain.owning_organization) }
        let(:host) { 'loggregator' }
        let(:route) { Route.new(domain: domain, space: space, host: host) }

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
            Route.make(domain: domain, space: space, host: host)
          end

          it 'is valid' do
            route_obj = Route.new(domain: domain, host: host, space: space, path: path)
            expect(route_obj).to be_valid
          end

          context 'and a user attempts to create the route in another space' do
            let(:another_space) { Space.make }

            it 'is not valid' do
              route_obj = Route.new(domain: domain, space: another_space, host: host, path: path)
              expect(route_obj).not_to be_valid
              expect(route_obj.errors.on([:domain_id, :host])).to include :host_and_domain_taken_different_space
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
              expect(route_obj.errors.on([:domain_id, :host])).to include :host_and_domain_taken_different_space
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
          route.port = 65536
          expect(route).not_to be_valid
        end

        it 'requires a host or port' do
          route.host = nil
          route.port = nil
          expect(route).not_to be_valid
        end

        it 'defaults the port to nil' do
          expect(route.port).to eq(nil)
        end

        context 'when port is specified' do
          let(:domain) { SharedDomain.make(router_group_guid: 'tcp-router-group') }
          let(:space_quota_definition) { SpaceQuotaDefinition.make }
          let(:space) { Space.make(space_quota_definition: space_quota_definition, organization: space_quota_definition.organization) }
          let(:routing_api_client) { double('routing_api_client', router_group: router_group) }
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
            expect {
              Route.make(space: space, port: 10, host: '', domain: domain)
            }.not_to raise_error
          end

          it 'validates the uniqueness of the port' do
            new_route = Route.new(space: space, port: 1, host: '', domain: domain)
            expect(new_route).not_to be_valid
            expect(new_route.errors.on([:host, :domain_id, :port])).to include :unique
          end
        end
      end

      context 'unescaped paths' do
        it 'validates uniqueness' do
          r = Route.make(path: '/a')

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: r.path)
          }.to raise_error(Sequel::ValidationFailed)

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/b')
          }.not_to raise_error
        end

        it 'does not allow two blank paths with same host and domain' do
          r = Route.make

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id)
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'is case-insensitive' do
          r = Route.make(path: '/path')

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/PATH')
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'escaped paths' do
        it 'validates uniqueness' do
          path = '/a%20path'
          r = Route.make(path: path)

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: path)
          }.to raise_error(Sequel::ValidationFailed)

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/b%20path')
          }.not_to raise_error
        end

        it 'allows another route with same host and domain but no path' do
          path = '/a%20path'
          r = Route.make(path: path)

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id)
          }.not_to raise_error
        end

        it 'allows a route with same host and domain with a path' do
          r = Route.make

          expect {
            Route.make(host: r.host, space_guid: r.space_guid, domain_id: r.domain_id, path: '/a/path')
          }.not_to raise_error
        end
      end

      context 'paths over 128 characters' do
        it 'raises exceeds valid length error' do
          path = '/path' * 100

          expect { Route.make(path: path) }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'host' do
        let(:space) { Space.make }
        let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

        before do
          route.space = space
          route.domain = domain
        end

        it 'should allow * to be the host name' do
          route.host = '*'
          expect(route).to be_valid
        end

        it 'should not allow * in the host name' do
          route.host = 'a*'
          expect(route).not_to be_valid
        end

        it 'should not allow . in the host name' do
          route.host = 'a.b'
          expect(route).not_to be_valid
        end

        it 'should not allow / in the host name' do
          route.host = 'a/b'
          expect(route).not_to be_valid
        end

        it 'should not allow a nil host' do
          expect {
            Route.make(space: space, domain: domain, host: nil)
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should allow an empty host' do
          Route.make(
            space: space,
            domain: domain,
            host: ''
          )
        end

        it 'should not allow a blank host' do
          expect {
            Route.make(
              space: space,
              domain: domain,
              host: ' '
            )
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow a long host' do
          expect {
            Route.make(
              space: space,
              domain: domain,
              host: 'f' * 63
            )
          }.to_not raise_error

          expect {
            Route.make(
              space: space,
              domain: domain,
              host: 'f' * 64
            )
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow a host which, along with the domain, exceeds the maximum length' do
          domain_200_chars = "#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 50}"
          domain_253_chars = "#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 49}.#{'f' * 50}.ff"
          domain = PrivateDomain.make(owning_organization: space.organization, name: domain_200_chars)
          domain_that_cannot_have_a_host = PrivateDomain.make(owning_organization: space.organization, name: domain_253_chars)

          valid_host = 'f' * 52
          invalid_host = 'f' * 53

          expect {
            Route.make(
              space: space,
              domain: domain,
              host: valid_host
            )
          }.to_not raise_error

          expect {
            Route.make(
              space: space,
              domain: domain_that_cannot_have_a_host,
              host: ''
            )
          }.to_not raise_error

          expect {
            Route.make(
              space: space,
              domain: domain,
              host: invalid_host
            )
          }.to raise_error(Sequel::ValidationFailed)
        end

        context 'shared domains' do
          it 'should not allow route to match existing domain' do
            SharedDomain.make name: 'bar.foo.com'
            expect {
              Route.make(
                space: space,
                domain: SharedDomain.make(name: 'foo.com'),
                host: 'bar'
              )
            }.to raise_error(Sequel::ValidationFailed, /domain_conflict/)
          end

          context 'when the host is missing' do
            it 'raises an informative error' do
              domain = SharedDomain.make name: 'bar.foo.com'
              expect {
                Route.make(
                  space: space,
                  domain: domain,
                  host: nil
                )
              }.to raise_error(Sequel::ValidationFailed, /host is required for shared-domains/)
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
            it 'should not validate the total routes limit if already existing' do
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
                allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client: routing_api_client))
              end

              before do
                space_quota.total_reserved_route_ports = 0
                space_quota.save
              end

              it 'is invalid' do
                expect(subject).to_not be_valid
                expect(subject.errors.on(:space)).to include :total_reserved_route_ports_exceeded
              end
            end
          end

          context 'on update' do
            it 'should not validate the total routes limit if already existing' do
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

        let(:http_route) { Route.new(space: space,
          domain: http_domain,
          host: 'bar')
        }
        subject(:tcp_route) { Route.new(space: space,
          domain: tcp_domain,
          host: '',
          port: 6000)
        }
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
                  expect(subject).to_not be_valid
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
                  expect(subject).to_not be_valid
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
                expect(subject).to_not be_valid
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

          it 'should not validate the total routes limit if already existing' do
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
      it { is_expected.to export_attributes :host, :domain_guid, :space_guid, :path, :service_instance_guid, :port }
      it { is_expected.to import_attributes :host, :domain_guid, :space_guid, :app_guids, :path, :port }
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
          it 'should return the fqdn for the route' do
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
            it 'should return the fqdn for the route' do
              r = Route.make(
                host: 'www',
                domain: domain,
                space: space,
              )
              expect(r.fqdn).to eq("www.#{domain.name}")
            end
          end

          context 'for a nil host' do
            it 'should return the fqdn for the route' do
              r = Route.make(
                host: '',
                domain: domain,
                space: space,
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
          it 'should return the fqdn with path' do
            r = Route.make(
              host: 'www',
              domain: domain,
              space: space,
              path: '/path'
            )
            expect(r.uri).to eq("www.#{domain.name}/path")
          end
          context 'that has a port' do
            it 'should return the fqdn with the path and port' do
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
          it 'should return the fqdn' do
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
            space: space,
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
            })
        end
      end

      describe '#in_suspended_org?' do
        let(:space) { Space.make }
        subject(:route) { Route.new(space: space) }

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

      it 'should not allow creation of a empty host on a shared domain' do
        shared_domain = SharedDomain.make

        expect {
          Route.make(
            host: '',
            space: space_a,
            domain: shared_domain
          )
        }.to raise_error Sequel::ValidationFailed
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

        route = Route.make(space: space)
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

            expect {
              route.destroy
            }.to raise_error VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse
            expect(RouteBinding.find(guid: route_binding_guid)).to eq route_binding
            expect(process.reload.routes[0]).to eq route
          end
        end
      end
    end

    def assert_valid_path(path)
      r = Route.make(path: path)
      expect(r).to be_valid
    end

    def assert_invalid_path(path)
      expect {
        Route.make(path: path)
      }.to raise_error(Sequel::ValidationFailed)
    end

    context 'decoded paths' do
      it 'should not allow a path of just slash' do
        assert_invalid_path('/')
      end

      it 'should allow a blank path' do
        assert_valid_path('') # kinda weird but it's like not having a path
      end

      it 'should not allow path that does not start with a slash' do
        assert_invalid_path('bar')
      end

      it 'should allow a path starting with a slash' do
        assert_valid_path('/foo')
      end

      it 'should allow a multi-part path' do
        assert_valid_path('/foo/bar')
      end

      it 'should allow a multi-part path ending with a slash' do
        assert_valid_path('/foo/bar/')
      end

      it 'should allow equal sign as part of the path' do
        assert_valid_path('/foo=bar')
      end

      it 'should not allow question mark' do
        assert_invalid_path('/foo?a=b')
      end

      it 'should not allow trailing question mark' do
        assert_invalid_path('/foo?')
      end

      it 'should not allow non-ASCII characters in the path' do
        assert_invalid_path('/barΩ')
      end
    end

    context 'encoded paths' do
      it 'should not allow a path of just slash' do
        assert_invalid_path('%2F')
      end
      it 'should allow a path of just slash' do
        assert_invalid_path('%2F')
      end

      it 'should not allow a path that does not start with slash' do
        assert_invalid_path('%20space')
      end

      it 'should allow a path that contains ?' do
        assert_valid_path('/%3F')
      end

      it 'should allow a path that begins with an escaped slash' do
        assert_invalid_path('%2Fpath')
      end

      it 'should allow  all other escaped chars in a proper url' do
        assert_valid_path('/a%20space')
      end
    end

    context '#internal?' do
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
          expect(internal_route.internal?).to eq(true)
        end
      end

      context 'when the route has a non-internal domain' do
        it 'is false' do
          expect(external_private_route.internal?).to eq(false)
        end
      end
    end

    describe 'vip_offset' do
      before do
        TestConfig.override(
          internal_route_vip_range: '127.128.99.0/29',
          kubernetes: {}
        )
      end

      context 'auto-assign vip_offset' do
        let(:internal_domain) { SharedDomain.make(name: 'apps.internal', internal: true) }
        let!(:internal_route_1) { Route.make(host: 'meow', domain: internal_domain) }
        let!(:internal_route_2) { Route.make(host: 'woof', domain: internal_domain) }
        let!(:internal_route_3) { Route.make(host: 'quack', domain: internal_domain) }
        let(:external_private_route) { Route.make }

        context 'when the Kubernetes API is not configured' do
          before do
            TestConfig.override( # 8 theoretical available ips, 6 actual
              internal_route_vip_range: '127.128.99.0/29',
              kubernetes: {}
            )
          end

          it 'auto-assigns vip_offset to internal routes only' do
            expect(internal_route_1.vip_offset).not_to be_nil
            expect(external_private_route.vip_offset).to be_nil
          end

          it 'assigns multiple vips in ascending order without duplicates' do
            expect(internal_route_1.vip_offset).to eq(1)
            expect(internal_route_2.vip_offset).to eq(2)
          end

          it 'never assigns the same vip_offset to multiple internal routes' do
            expect {
              Route.make(host: 'ants', vip_offset: 1)
            }.to raise_error(Sequel::UniqueConstraintViolation, /duplicate.*routes_vip_offset_index/i)
          end

          it 'finds an available offset' do
            Route.make(host: 'gulp', domain: internal_domain)
            expect(Route.select_map(:vip_offset)).to match_array((1..4).to_a)
          end

          context 'when the taken offset is not the first' do
            before do
              TestConfig.override(
                kubernetes: {}
              )
            end
            it 'finds the first offset' do
              internal_route_1.destroy
              expect(Route.make(host: 'gulp', domain: internal_domain).vip_offset).to eq(1)
            end
          end

          context 'when the taken offsets include first and not second' do
            it 'finds an available offset' do
              internal_route_2.destroy
              expect(Route.make(host: 'gulp', domain: internal_domain).vip_offset).to eq(2)
            end
          end

          context 'when filling the vip range' do
            it 'can make 3 more new routes only' do
              expect { Route.make(host: 'route4', domain: internal_domain) }.not_to raise_error
              expect { Route.make(host: 'route5', domain: internal_domain) }.not_to raise_error
              expect { Route.make(host: 'route6', domain: internal_domain) }.not_to raise_error
              expect { Route.make(host: 'route7', domain: internal_domain) }.to raise_error(Route::OutOfVIPException)
            end

            it 'can reclaim lost vips' do
              expect { Route.make(host: 'route4', domain: internal_domain) }.not_to raise_error
              expect { Route.make(host: 'route5', domain: internal_domain) }.not_to raise_error
              expect { Route.make(host: 'route6', domain: internal_domain) }.not_to raise_error
              Route.last.destroy
              internal_route_2.destroy
              expect(Route.make(host: 'new2', domain: internal_domain).vip_offset).to eq(2)
              expect(Route.make(host: 'new6', domain: internal_domain).vip_offset).to eq(6)
            end
          end
        end
      end

      context 'when we assign vip_offsets explicitly' do
        let(:internal_domain) { SharedDomain.make(name: 'apps.internal', internal: true) }

        it 'does not assign vip_offsets that exceed the CIDR range' do
          expect {
            Route.make(host: 'ants0', domain: internal_domain, vip_offset: 0)
          }.to raise_error(Sequel::ValidationFailed, 'name vip_offset')
          expect {
            Route.make(host: 'ants1', domain: internal_domain, vip_offset: 1)
          }.not_to raise_error
          expect {
            Route.make(host: 'ants6', domain: internal_domain, vip_offset: 6)
          }.not_to raise_error
          expect {
            Route.make(host: 'ants7', domain: internal_domain, vip_offset: 7)
          }.to raise_error(Sequel::ValidationFailed, 'name vip_offset')
          expect {
            Route.make(host: 'ants8', domain: internal_domain, vip_offset: 8)
          }.to raise_error(Sequel::ValidationFailed, 'name vip_offset')
        end
      end

      context 'when there are routes on internal domains' do
        let(:internal_domain) { SharedDomain.make(name: 'apps.internal', internal: true) }
        let!(:internal_route_1) { Route.make(host: 'meow', domain: internal_domain, vip_offset: nil) }
        let!(:internal_route_2) { Route.make(host: 'woof', domain: internal_domain, vip_offset: 2) }
        let!(:internal_route_3) { Route.make(host: 'quack', domain: internal_domain, vip_offset: 4) }
        let(:external_private_route) { Route.make }

        it 'can have different vip_offsets in range' do
          expect(internal_route_1).to be_valid
          expect(internal_route_1.vip_offset).to eq(1)
          expect(internal_route_2).to be_valid
          expect(internal_route_3).to be_valid
        end

        it 'assigns lowest-possible vip_offsets' do
          internal_route_4 = Route.make(host: 'bray', domain: internal_domain)
          expect(internal_route_4.vip_offset).to eq(3)
          internal_route_5 = Route.make(host: 'lemons', domain: internal_domain)
          expect(internal_route_5.vip_offset).to eq(5)
        end

        it 'reuses vip_offsets' do
          expected_vip_offset = internal_route_2.vip_offset
          internal_route_2.delete
          internal_route_6 = Route.make(host: 'route6', domain: internal_domain)
          expect(internal_route_6.vip_offset).to eq(expected_vip_offset)
        end
      end
    end

    describe 'vip' do
      before do
        TestConfig.override(
          kubernetes: {}
        )
      end

      let(:internal_domain) { SharedDomain.make(name: 'apps.internal', internal: true) }
      let!(:internal_route_1) { Route.make(host: 'meow', domain: internal_domain, vip_offset: 1) }
      let!(:internal_route_2) { Route.make(host: 'woof', domain: internal_domain, vip_offset: 2) }
      let!(:internal_route_3) { Route.make(host: 'quack', domain: internal_domain, vip_offset: 4) }
      let(:external_private_route) { Route.make }

      it 'returns a ipv4 ip address offset from the beginning of the internal route vip range' do
        expect(internal_route_1.vip).to eq('127.128.0.1')
        internal_route_2.vip_offset = 16
        expect(internal_route_2.vip).to eq('127.128.0.16')
      end

      it 'returns nil when asked for the ip addr for a nil offset' do
        expect(external_private_route.vip).to be_nil
      end
    end

    context '#wildcard_host?' do
      let!(:route) { Route.make(host: host) }
      context 'when the host is *' do
        let(:host) { '*' }
        it 'returns true' do
          expect(route.wildcard_host?).to eq(true)
        end
      end

      context 'when the host is not *' do
        let(:host) { 'meow' }
        it 'returns false' do
          expect(route.wildcard_host?).to eq(false)
        end
      end
    end
  end
end
