require 'spec_helper'
require 'actions/domain_delete'

module VCAP::CloudController
  RSpec.describe DomainDelete do
    subject(:domain_delete) { DomainDelete.new }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: org) }

    before do
      TestConfig.override(kubernetes: {})
    end

    describe '#delete' do
      let!(:domain) { Domain.make(owning_organization: org) }

      it 'deletes the domain record' do
        expect do
          domain_delete.delete([domain])
        end.to change(Domain, :count).by(-1)
        expect { domain.refresh }.to raise_error Sequel::Error, 'Record not found'
      end

      describe 'recursive deletion' do
        let(:app) { AppModel.make }
        let(:process_type) { 'web' }
        let(:process) { ProcessModel.make(app: app, type: process_type) }
        let(:route) { Route.make(domain: domain, space: space, host: 'test') }
        let(:service_instance) { ManagedServiceInstance.make(:routing, space:) }
        let!(:route_binding) { RouteBinding.make(route:, service_instance:) }
        let!(:route_mapping) { RouteMappingModel.make(app: app, route: route, process_type: process_type, app_port: 8080) }

        before do
          stub_unbind(route_binding)
        end

        it 'deletes associated route mappings' do
          expect do
            domain_delete.delete([domain])
          end.to change(RouteMappingModel, :count).by(-1)
          expect(route).not_to exist
          expect(route_mapping).not_to exist
          expect(domain).not_to exist
        end

        it 'deletes associated route bindings' do
          expect do
            domain_delete.delete([domain])
          end.to change(RouteBinding, :count).by(-1)
          expect(route_binding).not_to exist
          expect(domain).not_to exist
        end

        it 'deletes routes' do
          expect do
            domain_delete.delete([domain])
          end.to change(Route, :count).by(-1)
          expect(route).not_to exist
          expect(domain).not_to exist
        end
      end
    end
  end
end
