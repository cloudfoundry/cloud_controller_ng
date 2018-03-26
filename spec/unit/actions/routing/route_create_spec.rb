require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouteCreate do
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
      access_validator_route_arg = nil

      before do
        allow(CopilotHandler).to receive(:new)
        allow(access_validator).to receive(:validate_access) { |_, route| access_validator_route_arg = route }
      end

      context 'when copilot is disabled' do
        it 'creates a route without notifying copilot' do
          expect {
            route = route_create.create_route(route_hash: route_hash)

            expect(access_validator).to have_received(:validate_access).with(:create, instance_of(Route))
            expect(access_validator_route_arg).to eq(route)
            expect(CopilotHandler).not_to have_received(:new)
            expect(route.host).to eq(host)
            expect(route.path).to eq(path)
          }.to change { Route.count }.by(1)
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
      end

      context 'when copilot is enabled' do
        before do
          TestConfig.override(copilot: { enabled: true })
          allow(CopilotHandler).to receive(:create_route)
        end

        it 'creates a route and notifies copilot' do
          expect {
            route = route_create.create_route(route_hash: route_hash)

            expect(access_validator).to have_received(:validate_access).with(:create, instance_of(Route))
            expect(access_validator_route_arg).to eq(route)
            expect(CopilotHandler).to have_received(:create_route).with(route)
            expect(route.host).to eq(host)
            expect(route.path).to eq(path)
          }.to change { Route.count }.by(1)
        end

        context 'when copilot handler raises an exception' do
          before do
            allow(CopilotHandler).to receive(:create_route).and_raise(CopilotHandler::CopilotUnavailable.new('some-error'))
            allow(logger).to receive(:error)
          end

          it 'creates a route and logs an error' do
            expect {
              route = route_create.create_route(route_hash: route_hash)

              expect(access_validator).to have_received(:validate_access).with(:create, instance_of(Route))
              expect(access_validator_route_arg).to eq(route)
              expect(CopilotHandler).to have_received(:create_route).with(route)
              expect(logger).to have_received(:error).with('failed communicating with copilot backend: some-error')
              expect(route.host).to eq(host)
              expect(route.path).to eq(path)
            }.to change { Route.count }.by(1)
          end
        end
      end
    end
  end
end
