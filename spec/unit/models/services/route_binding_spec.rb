require 'spec_helper'
require_relative 'service_operation_shared'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::RouteBinding, type: :model do
    let(:binding) { RouteBinding.new }
    it { is_expected.to have_timestamp_columns }

    describe '#new' do
      it 'has a guid when constructed' do
        expect(binding.guid).to be
      end
    end

    describe 'Associations' do
      it { is_expected.to have_associated :route }
      it { is_expected.to have_associated :service_instance }
    end

    describe 'Validations' do
      it 'must have a service instance' do
        binding.route = Route.make
        binding.valid?
        expect(binding.errors[:service_instance]).to eq [:presence]
      end

      it 'must have a route' do
        binding.service_instance = ManagedServiceInstance.make
        binding.valid?
        expect(binding.errors[:route]).to eq [:presence]
      end

      it 'requires a service instance to have route_forwarding enabled' do
        space = Space.make
        binding.route = Route.make space: space
        binding.service_instance = ManagedServiceInstance.make space: space

        binding.valid?
        expect(binding.errors[:service_instance]).to eq [:route_binding_not_allowed]
      end

      it 'requires a service instance and route be in the same space' do
        space = Space.make
        other_space = Space.make

        service_instance = ManagedServiceInstance.make(:routing, space: space)
        route = Route.make space: other_space

        binding.service_instance = service_instance
        binding.route = route

        binding.valid?
        expect(binding.errors[:service_instance]).to eq [:space_mismatch]
      end
    end

    describe '#save_with_new_operation' do
      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
      let(:route) { Route.make(space: space) }
      let(:route_service_url) { 'https://foo.com' }
      let(:route_binding) do
        RouteBinding.new(
          service_instance: service_instance,
          route: route,
        )
      end

      it 'updates attributes and creates a new last_operation object' do
        last_operation = {
          state: 'in progress',
          type: 'create',
          description: '10%'
        }
        attributes = {
          route_service_url: route_service_url
        }
        result = route_binding.save_with_new_operation(attributes, last_operation)

        expect(result).to eq(route_binding)
        expect(route_binding.service_instance).to eq(service_instance)
        expect(route_binding.route).to eq(route)
        expect(route_binding.route_service_url).to eq(route_service_url)
        expect(route_binding.last_operation.state).to eq 'in progress'
        expect(route_binding.last_operation.description).to eq '10%'
        expect(route_binding.last_operation.type).to eq 'create'
        expect(RouteBinding.count).to eq(1)
      end

      context 'when saving the binding operation fails' do
        it 'should rollback the binding' do
          invalid_new_operation = {
            state: 'will fail',
            broker_provided_operation: 'too long' * 10000
          }
          expect { route_binding.save_with_new_operation({}, invalid_new_operation) }.to raise_error(Sequel::DatabaseError)
          expect(RouteBinding.count).to eq(0)
        end
      end

      context 'when called twice' do
        it 'does saves the second operation' do
          route_binding.save_with_new_operation({}, { state: 'in progress', type: 'create', description: 'description' })
          route_binding.save_with_new_operation({}, { state: 'in progress', type: 'delete' })

          expect(route_binding.last_operation.state).to eq 'in progress'
          expect(route_binding.last_operation.type).to eq 'delete'
          expect(route_binding.last_operation.description).to eq nil
          expect(RouteBinding.count).to eq(1)
          expect(RouteBindingOperation.count).to eq(1)
        end
      end
    end

    it_behaves_like 'a model including the ServiceOperationMixin', RouteBinding, :route_binding_operation, RouteBindingOperation, :route_binding_id
  end
end
