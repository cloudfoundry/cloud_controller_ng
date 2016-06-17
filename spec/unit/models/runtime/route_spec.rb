require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Route, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe '#tcp?' do
      context 'when the route belongs to a shared domain' do
        context 'and that domain is a TCP domain' do
          let!(:tcp_domain) { SharedDomain.make(router_group_guid: 'guid') }

          context 'and the route has a port' do
            let(:route) { Route.new(domain: tcp_domain, port: 6000) }

            it 'returns true' do
              expect(route.tcp?).to equal(true)
            end
          end

          context 'and the route does not have a port' do
            let(:route) { Route.new(domain: tcp_domain) }

            it 'returns false' do
              expect(route.tcp?).to equal(false)
            end
          end

          context 'and that domain is not a TCP domain' do
            let!(:domain) { SharedDomain.make }

            context 'and the route has a port' do
              let(:route) { Route.new(domain: domain, port: 6000) }

              it 'returns false' do
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
      it { is_expected.to have_associated :apps, associated_instance: ->(route) { App.make(space: route.space) } }
      it { is_expected.to have_associated :route_mappings, associated_instance: ->(route) { RouteMappingModel.make(app: AppModel.make(space: route.space), route: route) } }
      it { is_expected.to have_associated :app_route_mappings, associated_instance: ->(route) { RouteMapping.make(app: App.make(space: route.space), route: route) } }

      context 'when bound to a service instance' do
        let(:route) { Route.make }
        let(:service_instance) { ManagedServiceInstance.make(:routing, space: route.space) }
        let!(:route_binding) { RouteBinding.make(route: route, service_instance: service_instance) }

        it 'has a service instance' do
          expect(route.service_instance).to eq service_instance
        end
      end

      context 'changing space' do
        context 'apps' do
          it 'succeeds with no mapped apps' do
            route = Route.make(space: AppFactory.make.space, domain: SharedDomain.make)

            expect { route.space = Space.make }.not_to raise_error
          end

          it 'fails when changing the space when there are apps mapped to it' do
            app = AppFactory.make
            route = Route.make(space: app.space, domain: SharedDomain.make)
            app.add_route(route)

            expect { route.space = Space.make }.to raise_error(Route::InvalidAppRelation)
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
                expect { route.space = Space.make }.to raise_error(Route::InvalidOrganizationRelation)
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

      context 'changing domain' do
        context 'when shared' do
          it "succeeds if it's the same domain" do
            domain = SharedDomain.make
            route        = Route.make(domain: domain)
            route.domain = route.domain = domain
            expect { route.save }.not_to raise_error
          end

          it "fails if it's different" do
            route        = Route.make(domain: SharedDomain.make)
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
            route        = Route.make(space: space, domain: domain)
            route.domain = PrivateDomain.make(owning_organization: space.organization)
            expect(route.valid?).to be_falsey
          end
        end
      end

      context 'deleting with route mappings' do
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

          before do
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
          allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client: routing_api_client))
        end

        context 'on create' do
          context 'when the space does not have a space quota' do
            let(:space) { Space.make }

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when not exceeding total allowed routes' do
            before do
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

      describe 'all_apps_diego?' do
        let(:diego_app) { AppFactory.make(diego: true) }
        let(:route) { Route.make(space: diego_app.space, domain: SharedDomain.make) }

        before do
          diego_app.add_route(route)
        end

        it 'returns true' do
          expect(route.all_apps_diego?).to eq(true)
        end

        context 'when some apps are not using diego' do
          let(:non_diego_app) { AppFactory.make(diego: false, space: diego_app.space) }

          before do
            non_diego_app.add_route(route)
          end

          it 'returns false' do
            expect(route.all_apps_diego?).to eq(false)
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

      it 'should not associate with apps from a different space' do
        route = Route.make(space: space_b, domain: domain_a)
        app   = AppFactory.make(space: space_a)
        expect {
          route.add_app(app)
        }.to raise_error Route::InvalidAppRelation
      end

      it 'should not allow creation of a empty host on a shared domain' do
        shared_domain = SharedDomain.make

        expect {
          Route.make(
            host:   '',
            space:  space_a,
            domain: shared_domain
          )
        }.to raise_error Sequel::ValidationFailed
      end

      context 'when docker is disabled' do
        subject(:route) { Route.make(space: space_a, domain: domain_a) }

        context 'when docker app is added to a route' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          let!(:docker_app) do
            AppFactory.make(space: space_a, docker_image: 'some-image', state: 'STARTED')
          end

          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          it 'should associate with the docker app' do
            expect { route.add_app(docker_app) }.not_to raise_error
          end
        end
      end
    end

    describe '#destroy' do
      it 'marks the apps routes as changed and sends an update to the dea' do
        space = Space.make
        app1   = AppFactory.make(space: space, state: 'STARTED', package_state: 'STAGED')
        app2   = AppFactory.make(space: space, state: 'STARTED', package_state: 'STAGED')

        route = Route.make(app_guids: [app1.guid, app2.guid], space: space)

        app1   = route.apps[0]
        app2   = route.apps[1]
        expect(app1).to receive(:handle_remove_route).and_call_original
        expect(app2).to receive(:handle_remove_route).and_call_original

        expect(Dea::Client).to receive(:update_uris).with(app1)
        expect(Dea::Client).to receive(:update_uris).with(app2)

        route.destroy
      end

      context 'with route bindings' do
        let(:route_binding) { RouteBinding.make }
        let(:route) { route_binding.route }
        let(:app) { AppFactory.make(space: route.space, diego: true) }

        before do
          app.add_route(route)
          stub_unbind(route_binding)
        end

        it 'deletes any associated route_bindings' do
          route_binding_guid = route_binding.guid

          route.destroy
          expect(RouteBinding.find(guid: route_binding_guid)).to be_nil
          expect(app.reload.routes).to be_empty
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
            expect(app.reload.routes[0]).to eq route
          end
        end
      end
    end

    describe 'apps association' do
      let(:route) { Route.make }
      let!(:app) do
        AppFactory.make({ space: route.space, diego: true, ports: [8080, 9090] })
      end

      describe 'when adding an app' do
        it 'marks the apps routes as changed and creates an audit event' do
          expect(app).to receive(:handle_add_route).and_call_original
          expect {
            route.add_app(app)
          }.to change { Event.count }.by(1)
        end

        context 'when a app is bound to multiple ports' do
          let!(:route_mapping1) { RouteMapping.make(app: app, route: route, app_port: 8080) }
          let!(:route_mapping2) { RouteMapping.make(app: app, route: route, app_port: 9090) }

          it 'returns a single app association' do
            expect(route.apps.length).to eq(1)
          end
        end

        context 'when the app has user provided ports' do
          let(:app) { App.make(diego: true, ports: [8998]) }
          let(:route) { Route.make(space: app.space) }

          before do
            route.add_app(app)
          end

          it 'should save app_port to the route mappings' do
            route_mapping = RouteMapping.last
            expect(route_mapping.user_provided_app_port).to eq 8998
          end
        end

        context 'when the app does not have user provided ports' do
          let(:app) { App.make(diego: true) }
          let(:route) { Route.make(space: app.space) }

          before do
            route.add_app(app)
          end

          it 'should not save app_port to the route mappings' do
            route_mapping = RouteMapping.last
            expect(route_mapping.user_provided_app_port).to be_nil
          end
        end

        context 'when the app is a dea' do
          let(:app) { App.make(diego: false) }
          let(:route) { Route.make(space: app.space) }

          before do
            route.add_app(app)
          end

          it 'should not have an app_port' do
            route_mapping = RouteMapping.last
            expect(route_mapping.app_port).to be_nil
          end
        end
      end

      describe 'when removing an app' do
        it 'marks the apps routes as changed and creates an audit event' do
          route.add_app(app)
          expect(app).to receive(:handle_remove_route).and_call_original
          expect {
            route.remove_app(app)
          }.to change { Event.count }.by(1)
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
  end
end
