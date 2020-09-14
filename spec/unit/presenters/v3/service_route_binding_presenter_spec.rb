require 'db_spec_helper'
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
            route_service_url: route_service_url,
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
            route_service_url: route_service_url,
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

      describe 'decorators' do
        let(:decorator1) { double('FakeDecorator', decorate: { foo: 'bar' }) }
        let(:decorator2) { double('FakeDecorator', decorate: { xyzzy: 'omg' }) }
        let(:decorators) { [decorator1, decorator2] }
        let(:presenter) { described_class.new(binding, decorators: decorators) }
        let!(:content) { presenter.to_hash }

        it 'adds the decorated information' do
          expect(content[:xyzzy]).to eq('omg')
          expect(content[:foo]).to be_nil
        end

        it 'sends the route to the decorator' do
          expect(decorator1).to have_received(:decorate).with({}, [binding])
          expect(decorator2).to have_received(:decorate).with({ foo: 'bar' }, [binding])
        end
      end
    end
  end
end
