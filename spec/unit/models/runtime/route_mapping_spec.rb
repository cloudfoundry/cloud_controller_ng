require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::RouteMapping, type: :model do
    let(:mapping) { RouteMapping.new }
    let(:space) { Space.make }
    it { is_expected.to have_timestamp_columns }

    describe 'Backwards Compatibility' do
      let(:app) { AppFactory.make }
      let(:route) { Route.make(space: app.space) }
      let!(:mapping) { RouteMapping.make }

      before do
        app.add_route(route)
      end

      it 'the model reads from new route_mappings table and old apps_routes table' do
        mappings = RouteMapping.all

        old_mapping = RouteMapping.new
        old_mapping.app = app
        old_mapping.route = route

        expect(mappings.size).to eq 2
        expect(mappings).to include(mapping)
        expect(mappings).to include(old_mapping)
      end
    end

    describe 'Associations' do
      let(:route) { Route.make(space: space) }
      let(:app) { App.make(space: space) }

      it { is_expected.to have_associated :app, associated_instance: ->(m) { app } }
      it { is_expected.to have_associated :route, associated_instance: ->(m) { route } }
    end

    describe 'Validations' do
      let(:org) { Organization.make }
      let(:space_a) { Space.make(organization: org) }
      let(:domain_a) { PrivateDomain.make(owning_organization: org) }

      let(:space_b) { Space.make(organization: org) }
      let(:domain_b) { PrivateDomain.make(owning_organization: org) }

      it 'should not associate with apps and routes from a different space' do
        route = Route.make(space: space_b, domain: domain_a)
        app   = AppFactory.make(space: space_a)
        expect {
          RouteMapping.make(app: app, route: route)
        }.to raise_error Errors::InvalidRouteRelation
      end

      context 'when docker is disabled' do
        let(:route) { Route.make(space: space_a, domain: domain_a) }

        context 'when docker app is added to a route' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          let!(:docker_app) do
            AppFactory.make(space: space_a, diego: true, docker_image: 'some-image', state: 'STARTED')
          end

          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
            allow(docker_app).to receive(:docker_ports).and_return([9999])
          end

          it 'should associate with the docker app' do
            expect { RouteMapping.make(app: docker_app, route: route) }.not_to raise_error
          end
        end
      end
    end

    describe 'creating' do
      let(:route) { Route.make(space: space) }
      context 'when the app is a diego app' do
        let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [8080]) }

        context 'and no app port is specified' do
          it 'uses the first port in the list of app ports' do
            mapping = RouteMapping.new(app: app_obj, route: route)
            mapping.save
            expect(mapping.app_port).to eq(8080)
          end
        end

        context 'and an app port is specified' do
          let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [1111]) }

          context 'and the port is not bound to the app' do
            it 'adds an error' do
              mapping = RouteMapping.new(app: app_obj, route: route, app_port: 2222)
              expect(mapping.valid?).to be_falsey
              expect(mapping.errors.on(:app_port)).to include :not_bound_to_app
            end
          end

          it 'uses the app port specified' do
            mapping = RouteMapping.new(app: app_obj, route: route, app_port: 1111)
            mapping.save
            expect(mapping.app_port).to eq(1111)
          end
        end
      end

      context 'when the app is a DEA app' do
        let(:app_obj) { AppFactory.make(space: space, diego: false) }

        context 'and app port is not specified' do
          it 'returns a 201' do
            mapping = RouteMapping.new(app: app_obj, route: route)
            mapping.save
            expect(mapping.app_port).to be_nil
          end
        end

        context 'and app port is specified' do
          it 'adds an error' do
            mapping = RouteMapping.new(app: app_obj, route: route, app_port: 1111)
            expect(mapping.valid?).to be_falsey
            expect(mapping.errors.on(:app_port)).to include :diego_only
          end
        end
      end
    end

    describe 'apps association' do
      let(:route) { Route.make }
      let!(:app) do
        AppFactory.make(space: route.space)
      end

      describe 'when adding an app' do
        it 'marks the apps routes as changed and creates an audit event' do
          expect(app).to receive(:handle_add_route).and_call_original
          expect {
            RouteMapping.make(app: app, route: route)
          }.to change { Event.count }.by(1)
        end
      end

      context 'when the route is bound to a routing service' do
        let(:app) { AppFactory.make(diego: diego?, ports: ports) }
        let(:route_with_service) do
          route = Route.make(host: 'myhost', space: app.space, path: '/my%20path')
          service_instance = ManagedServiceInstance.make(:routing, space: app.space)
          RouteBinding.make(route: route, service_instance: service_instance)
          route
        end

        context 'and the app uses diego' do
          let(:diego?) { true }
          let(:ports) { [8080] }
          it 'does not raise an error' do
            expect {
              RouteMapping.make(app: app, route: route_with_service)
            }.not_to raise_error
          end
        end

        context 'and the app does not use diego' do
          let(:diego?) { false }
          let(:ports) { nil }
          it 'to raise error' do
            expect {
              RouteMapping.make(app: app, route: route_with_service)
            }.to raise_error(Errors::InvalidRouteRelation).
              with_message("The requested route relation is invalid: #{route_with_service.guid} - Route services are only supported for apps on Diego")
          end
        end
      end

      context 'when adding and removing routes', isolation: :truncation do
        let(:domain) do
          PrivateDomain.make owning_organization: app.space.organization
        end
        let(:app) { AppFactory.make(space: route.space, diego: true, ports: [1111]) }

        before do
          allow(AppObserver).to receive(:routes_changed).with(app)
          process_guid = Diego::ProcessGuid.from_app(app)
          stub_request(:delete, "#{TestConfig.config[:diego_nsync_url]}/v1/apps/#{process_guid}").to_return(status: 202)
        end

        it 'does not update the app version' do
          expect { RouteMapping.make(app: app, route: route) }.to_not change(app, :version)
        end

        it 'calls the app observer with the app' do
          expect(AppObserver).to receive(:routes_changed).with(app)
          RouteMapping.make(app: app, route: route)
        end
      end
    end
  end
end
