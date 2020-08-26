require 'spec_helper'
require 'presenters/v3/service_route_binding_presenter'

module VCAP
  module CloudController
    RSpec.describe Presenters::V3::ServiceRouteBindingPresenter do
      let(:space) { VCAP::CloudController::Space.make }
      let(:route_service_url) { 'https://route_service_url.com' }
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space: space, route_service_url: route_service_url) }
      let(:route) { Route.make(space: space) }
      let(:guid) { Sham.guid }
      let(:binding) do
        RouteBinding.new.save_with_new_operation(
          {
          guid: guid,
          service_instance: service_instance,
          route: route,
          },
          {
            type: 'fake type',
            state: 'fake state',
            description: 'fake description',
          }
        )
      end

      it 'presents the correct object' do
        presenter = described_class.new(binding)
        expect(presenter.to_hash).to match(
          {
            guid: guid,
            created_at: binding.created_at,
            updated_at: binding.updated_at,
            last_operation: {
              type: 'fake type',
              state: 'fake state',
              description: 'fake description',
              updated_at: binding.last_operation.updated_at,
              created_at: binding.last_operation.created_at
            },
            relationships: {
              route: {
                data: {
                  guid: route.guid
                }
              },
              service_instance: {
                data: {
                  guid: service_instance.guid
                }
              }
            },
            links: {
              self: {
                href: %r{.*/v3/service_route_bindings/#{guid}}
              },
              route: {
                href: %r{.*/v3/routes/#{route.guid}}
              },
              service_instance: {
                href: %r{.*/v3/service_instances/#{service_instance.guid}}
              }
            }
          }
        )
      end
    end
  end
end
