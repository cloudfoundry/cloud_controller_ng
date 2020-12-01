require 'spec_helper'

module VCAP::CloudController
  module V2
    RSpec.describe RouteCreate do
      let(:route_resource_manager) { instance_double(Kubernetes::RouteResourceManager) }
      let(:access_validator) { instance_double(RoutesController) }
      let(:logger) { instance_double(Steno::Logger) }
      let(:route_create) { RouteCreate.new(access_validator: access_validator, logger: logger) }
      let(:host) { 'some-host' }
      let(:space_quota_definition) { SpaceQuotaDefinition.make }
      let(:space) do
        Space.make(space_quota_definition: space_quota_definition,
          organization: space_quota_definition.organization)
      end
      let(:domain) { SharedDomain.make }
      let(:path) { '/some-path' }
      let(:route_hash) do
        {
          host: host,
          domain_guid: domain.guid,
          space_guid: space.guid,
          path: path
        }
      end

      describe '#create_route' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:route_resource_manager).and_return(route_resource_manager)
          allow(route_resource_manager).to receive(:create_route)

          allow(access_validator).to receive(:validate_access)
        end

        context 'when access validation fails' do
          before do
            allow(access_validator).to receive(:validate_access).and_raise('some-exception')
          end

          it 'should not create a route in the db' do
            expect {
              begin
                route_create.create_route(route_hash: route_hash)
              rescue
              end
            }.not_to change { Route.count }
          end

          it 'should bubble up the exception' do
            expect { route_create.create_route(route_hash: route_hash) }.to raise_error('some-exception')
          end
        end

        context 'when targeting a Kubernetes API' do
          before do
            TestConfig.override(kubernetes: { host_url: 'https://kubernetes.example.com' })
          end

          it 'creates a route resource in Kubernetes' do
            expect {
              route = route_create.create_route(route_hash: route_hash)

              expect(access_validator).to have_received(:validate_access).with(:create, route)
              expect(route_resource_manager).to have_received(:create_route).with(route)
              expect(route.host).to eq(host)
              expect(route.path).to eq(path)
            }.to change { Route.count }.by(1)
          end
        end

        context 'when not targeting a Kubernetes API' do
          before do
            TestConfig.override(kubernetes: {})
          end

          it 'does not create a route resource in Kubernetes' do
            expect {
              route = route_create.create_route(route_hash: route_hash)

              expect(access_validator).to have_received(:validate_access).with(:create, route)
              expect(route_resource_manager).not_to have_received(:create_route)
              expect(route.host).to eq(host)
              expect(route.path).to eq(path)
            }.to change { Route.count }.by(1)
          end
        end
      end
    end
  end
end
