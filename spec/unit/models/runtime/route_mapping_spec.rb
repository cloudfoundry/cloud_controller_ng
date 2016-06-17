require 'spec_helper'
module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RouteMapping, type: :model do
    let(:mapping) { RouteMapping.new }
    let(:space) { Space.make }
    it { is_expected.to have_timestamp_columns }

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

      let(:route) { Route.make(space: space) }

      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :route }

      context 'when the app is a diego app' do
        let(:app) { AppFactory.make(diego: true, space: space, ports: [1111, 2222]) }

        it 'validates uniqueness of route, app, and app_port' do
          RouteMapping.make(app: app, route: route)

          invalid_mapping = RouteMapping.new(app: app, route: route)
          expect(invalid_mapping).not_to be_valid
          expect(invalid_mapping.errors.on([:app_id, :route_id, :app_port])).to include :unique
        end

        it 'allows the same route and app but different app_ports' do
          RouteMapping.make(app: app, route: route, app_port: 1111)

          valid_mapping = RouteMapping.new(app: app, route: route, app_port: 2222)
          expect(valid_mapping).to be_valid
        end
      end

      context 'when the app is a DEA app' do
        let(:app) { AppFactory.make(diego: false, space: space) }

        it 'validates uniqueness of route and app' do
          RouteMapping.make(app: app, route: route)

          invalid_mapping = RouteMapping.new(app: app, route: route)
          expect(invalid_mapping).not_to be_valid
          expect(invalid_mapping.errors.on([:app_id, :route_id])).to include :unique
        end
      end

      it 'should not associate with apps and routes from a different space' do
        route = Route.make(space: space_b, domain: domain_a)
        app   = AppFactory.make(space: space_a)
        expect {
          RouteMapping.make(app: app, route: route)
        }.to raise_error CloudController::Errors::InvalidRouteRelation
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
        let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [9090]) }

        context 'and no app port is specified' do
          it 'uses the first port in the list of app ports' do
            mapping = RouteMapping.new(app: app_obj, route: route)
            mapping.save
            expect(mapping.app_port).to eq(9090)
          end

          it 'saves the app port to the database' do
            mapping = RouteMapping.new(app: app_obj, route: route)
            mapping.save
            expect(mapping.user_provided_app_port).to eq(9090)
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
            expect(mapping.user_provided_app_port).to eq(1111)
          end
        end
      end

      context 'when the app is a DEA app' do
        let(:app_obj) { AppFactory.make(space: space, diego: false) }

        context 'and app port is not specified' do
          it 'sets app port to nil' do
            mapping = RouteMapping.new(app: app_obj, route: route)
            mapping.save
            expect(mapping.app_port).to be_nil
            expect(mapping.user_provided_app_port).to be_nil
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

      context 'with null guid' do
        let(:app_obj) { AppFactory.make(space: space, diego: true, ports: [8080]) }
        before do
          RouteMapping.db.run("insert into apps_routes (app_id, route_id) values (#{app_obj.id}, #{route.id})")
        end

        it 'auto assigns a guid during read' do
          mapping = RouteMapping.find(app_id: app_obj.id, route_id: route.id)
          expect(mapping.guid).to_not be_nil
        end
      end
    end

    describe 'Docker mappings' do
      let(:app_obj) { App.make(diego: true, docker_image: 'some-docker-image', package_state: 'PENDING') }
      let(:route) { Route.make(space: app_obj.space) }

      context 'when the app has no docker ports' do
        it 'is nil' do
          mapping = RouteMapping.new(app: app_obj, route: route)
          mapping.save
          expect(mapping.app_port).to be nil
        end

        it 'does not save the app port' do
          mapping = RouteMapping.new(app: app_obj, route: route)
          mapping.save
          expect(mapping.user_provided_app_port).to be_nil
        end
      end

      context 'when the app has docker ports' do
        let(:app_obj) do
          app = App.make(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
          app.add_droplet(Droplet.new(
                            app: app,
                            droplet_hash: 'the-droplet-hash',
                            execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
                          ))
          app.droplet_hash = 'the-droplet-hash'
          app
        end

        let(:mapping) { RouteMapping.new(app: app_obj, route: route) }

        it 'returns nil app_port' do
          mapping.save
          expect(mapping.app_port).to be nil
        end

        it 'does not save app_port' do
          mapping.save
          expect(mapping.user_provided_app_port).to be_nil
        end

        context 'and the app does have user provided ports' do
          before do
            app_obj.ports = [7777, 5555]
            app_obj.save
          end

          it 'returns the first user provided port' do
            mapping.save
            expect(mapping.app_port).to eq 7777
          end

          it 'does save the app_port' do
            mapping.save
            expect(mapping.user_provided_app_port).to eq 7777
          end
        end
      end
    end

    describe 'apps association' do
      let(:route) { Route.make }
      let(:app) do
        AppFactory.make(space: route.space)
      end

      describe 'when adding a route mapping' do
        it 'marks the apps routes as changed and creates an audit event' do
          expect(app).to receive(:handle_add_route).and_call_original
          expect {
            RouteMapping.make(app: app, route: route)
          }.to change { Event.count }.by(1)
        end
      end

      describe 'when deleting a route mapping' do
        let!(:route_mapping) { RouteMapping.make(app: app, route: route) }

        it 'marks the apps routes as changed and creates an audit event' do
          expect_any_instance_of(App).to receive(:handle_remove_route).and_call_original
          expect {
            route_mapping.destroy
          }.to change { Event.count }.by(1)
        end
      end

      context 'when a dea app is moved to diego' do
        let!(:app) { AppFactory.make(diego: false) }
        let!(:route) { Route.make(space: app.space) }

        before do
          RouteMapping.make(app: app, route: route)
          app.diego = true
          app.save
        end

        it 'returns a nil app_port' do
          route_mapping = RouteMapping.last
          expect(route_mapping.app_port).to be nil
        end

        it 'does not save the user_provided_app_port' do
          route_mapping = RouteMapping.last
          expect(route_mapping.user_provided_app_port).to be nil
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
            }.to raise_error(CloudController::Errors::InvalidRouteRelation).
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
          process_guid = Diego::ProcessGuid.from_process(app)
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

      context 'when the app port is null' do
        context 'when the associated app has ports' do
          let(:app) { AppFactory.make(space: space, diego: true, ports: [1111, 1112]) }
          let(:route) { Route.make('myhost', space: app.space, path: '/my%20path') }
          let(:route_mapping) { RouteMapping.make(app: app, route: route) }

          it 'saves app_port and returns the first app port' do
            expect(route_mapping.user_provided_app_port).to equal 1111
            expect(route_mapping.app_port).to equal 1111
          end
        end

        context 'when the associated app has no ports' do
          context 'when the app is a diego app' do
            let(:app) { AppFactory.make(space: space, diego: true) }
            let(:route) { Route.make('myhost', space: app.space, path: '/my%20path') }
            let(:route_mapping) { RouteMapping.make(app: app, route: route) }

            it 'is nil' do
              expect(route_mapping.app_port).to be nil
            end

            it 'does not save the default port' do
              expect(route_mapping.user_provided_app_port).to be_nil
            end
          end

          context 'when the app is not a diego app' do
            let(:app) { AppFactory.make(space: space, diego: false) }
            let(:route) { Route.make('myhost', space: app.space, path: '/my%20path') }
            let(:route_mapping) { RouteMapping.make(app: app, route: route) }

            it 'returns nil' do
              expect(route_mapping.app_port).to be nil
              expect(route_mapping.user_provided_app_port).to be nil
            end
          end
        end
      end
    end
  end
end
