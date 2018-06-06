require 'spec_helper'
require 'actions/v3/route_create'

module VCAP::CloudController
  module V3
    RSpec.describe RouteCreate do
      let(:logger) { instance_double(Steno::Logger) }
      let(:user_audit_info) { instance_double(UserAuditInfo) }
      let(:route_event_repo) { instance_double(Repositories::RouteEventRepository) }
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
          allow(Copilot::Adapter).to receive(:new)
          allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
          allow(route_event_repo).to receive(:record_route_create)
        end

        describe 'audit events' do
          it 'records an audit event' do
            route = RouteCreate.create_route(route_hash: route_hash, logger: logger, user_audit_info: user_audit_info)
            expect(route_event_repo).to have_received(:record_route_create).with(route, user_audit_info, route_hash, manifest_triggered: false)
          end

          context 'when the route create is triggered by applying a manifest' do
            it 'tags the audit event with manifest_triggered: true' do
              route = RouteCreate.create_route(route_hash: route_hash, logger: logger, user_audit_info: user_audit_info, manifest_triggered: true)
              expect(route_event_repo).to have_received(:record_route_create).with(route, user_audit_info, route_hash, manifest_triggered: true)
            end
          end
        end

        context 'when copilot is disabled' do
          it 'creates a route without notifying copilot' do
            expect {
              route = RouteCreate.create_route(route_hash: route_hash, logger: logger, user_audit_info: user_audit_info)

              expect(Copilot::Adapter).not_to have_received(:new)
              expect(route_event_repo).to have_received(:record_route_create).with(route, user_audit_info, route_hash, manifest_triggered: false)
              expect(route.host).to eq(host)
              expect(route.path).to eq(path)
            }.to change { Route.count }.by(1)
          end
        end

        context 'when copilot is enabled' do
          before do
            TestConfig.override(copilot: { enabled: true })
            allow(Copilot::Adapter).to receive(:create_route)
            allow(Repositories::RouteEventRepository).to receive(:new).and_return(route_event_repo)
            allow(route_event_repo).to receive(:record_route_create)
          end

          it 'creates a route and notifies copilot' do
            expect {
              route = RouteCreate.create_route(route_hash: route_hash, logger: logger, user_audit_info: user_audit_info)

              expect(Copilot::Adapter).to have_received(:create_route).with(route)
              expect(route_event_repo).to have_received(:record_route_create).with(route, user_audit_info, route_hash, manifest_triggered: false)
              expect(route.host).to eq(host)
              expect(route.path).to eq(path)
            }.to change { Route.count }.by(1)
          end

          context 'when copilot handler raises an exception' do
            before do
              allow(Copilot::Adapter).to receive(:create_route).and_raise(Copilot::Adapter::CopilotUnavailable.new('some-error'))
              allow(logger).to receive(:error)
            end

            it 'creates a route and logs an error' do
              expect {
                route = RouteCreate.create_route(route_hash: route_hash, logger: logger, user_audit_info: user_audit_info)

                expect(Copilot::Adapter).to have_received(:create_route).with(route)
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
end
