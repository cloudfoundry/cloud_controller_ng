require 'spec_helper'

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

    describe 'operation_in_progress?' do
      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
      let(:route) { Route.make(space: space) }
      let(:route_binding) do
        RouteBinding.make(
          service_instance: service_instance,
          route: route,
        )
      end

      context 'when the route binding has been created synchronously' do
        it 'returns false' do
          expect(route_binding.operation_in_progress?).to be false
        end
      end

      context 'when the route binding is being created asynchronously' do
        let(:state) {}
        let(:operation) { RouteBindingOperation.make(state: state) }

        before do
          route_binding.route_binding_operation = operation
        end

        context 'and the operation is in progress' do
          let(:state) { 'in progress' }

          it 'returns true' do
            expect(route_binding.operation_in_progress?).to be true
          end
        end

        context 'and the operation has failed' do
          let(:state) { 'failed' }

          it 'returns false' do
            expect(route_binding.operation_in_progress?).to be false
          end
        end

        context 'and the operation has succeeded' do
          let(:state) { 'succeeded' }

          it 'returns false' do
            expect(route_binding.operation_in_progress?).to be false
          end
        end
      end
    end

    describe '#terminal_state?' do
      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan) }
      let(:route) { Route.make(space: space) }

      def build_binding_with_op_state(state)
        binding = RouteBinding.make(
          service_instance: service_instance,
          route: route,
        )
        binding.route_binding_operation = RouteBindingOperation.make(state: state)
        binding
      end

      it 'returns true when state is `succeeded`' do
        binding = build_binding_with_op_state('succeeded')
        expect(binding.terminal_state?).to be true
      end

      it 'returns true when state is `failed`' do
        binding = build_binding_with_op_state('failed')
        expect(binding.terminal_state?).to be true
      end

      it 'returns false otherwise' do
        binding = build_binding_with_op_state('other')
        expect(binding.terminal_state?).to be false
      end
    end
  end
end
