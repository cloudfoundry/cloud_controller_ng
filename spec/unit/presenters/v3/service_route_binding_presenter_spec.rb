require 'db_spec_helper'
require 'presenters/v3/service_route_binding_presenter'
require 'actions/labels_update'
require 'actions/annotations_update'

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

      before do
        LabelsUpdate.update(binding, { ruby: 'lang' }, RouteBindingLabelModel)
        AnnotationsUpdate.update(binding, { 'prefix/key' => 'bar' }, RouteBindingAnnotationModel)
      end

      it 'presents the correct object' do
        presenter = described_class.new(binding)
        expect(presenter.to_hash.with_indifferent_access).to match(
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
            metadata: {
              labels: {
                ruby: 'lang',
              },
              annotations: {
                'prefix/key' => 'bar'
              }
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
              },

            }
          }
        )
      end

      context 'no last_operation' do
        let(:binding) do
          RouteBinding.make(
            guid: guid,
            service_instance: service_instance,
            route: route,
            route_service_url: route_service_url,
          )
        end

        it 'still displays the last operation' do
          presenter = described_class.new(binding)
          expect(presenter.to_hash[:last_operation]).to match(
            {
              type: 'create',
              state: 'succeeded',
              description: '',
              updated_at: binding.updated_at,
              created_at: binding.created_at
            }
          )
        end
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

      describe 'links' do
        let(:offering) { VCAP::CloudController::Service.make(requires: ['route_forwarding']) }
        let(:plan) { VCAP::CloudController::ServicePlan.make(service: offering) }
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: plan) }

        it 'include parameters for managed service instance bindings' do
          presenter = described_class.new(binding)
          expect(presenter.to_hash.dig(:links, :parameters)).to match({
            href: %r{.*/v3/service_route_bindings/#{guid}/parameters}
          })
        end
      end
    end
  end
end
