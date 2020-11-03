require 'db_spec_helper'
require 'support/shared_examples/jobs/delete_binding_job'
require 'jobs/v3/delete_binding_job'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteBindingJob do
      context 'route' do
        let(:route) { VCAP::CloudController::Route.make(space: space) }
        let(:binding) do
          RouteBinding.new.save_with_attributes_and_new_operation(
            {
              service_instance: service_instance,
              route: route,
            },
            {
              type: 'create',
              state: 'in progress'
            },
          )
        end

        it_behaves_like 'delete binding job', :route
      end

      context 'credential bindings' do
        let(:binding) do
          ServiceBinding.new.save_with_attributes_and_new_operation(
            {
              type: 'app',
              service_instance: service_instance,
              app: AppModel.make(space: service_instance.space),
              credentials: {
                test: 'secretPassword'
              },
            },
            {
              type: 'create',
              state: 'in progress'
            },
          )
        end

        it_behaves_like 'delete binding job', :credential
      end

      let(:subject) do
        described_class.new(
          :any,
          'foo',
          user_audit_info: {},
        )
      end

      describe '#actor' do
        let(:actor) do
          instance_double(VCAP::CloudController::V3::DeleteServiceCredentialBindingJobActor)
        end

        before do
          allow(VCAP::CloudController::V3::DeleteServiceBindingFactory).to receive(:for).and_return(actor)
        end

        it 'returns the actor' do
          expect(subject.actor).to be(actor)
        end
      end

      describe '#operation' do
        it 'returns "unbind"' do
          expect(subject.operation).to eq(:unbind)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(subject.operation_type).to eq('delete')
        end
      end

      describe '#display_name' do
        let(:actor) { double('Actor', display_name: 'wonder') }

        before do
          allow(VCAP::CloudController::V3::DeleteServiceBindingFactory).to receive(:for).and_return(actor)
        end

        it 'returns the actor display name' do
          expect(subject.display_name).to eq('wonder')
        end
      end

      describe '#resource_type' do
        let(:actor) { double('Actor', resource_type: 'super') }
        before do
          allow(VCAP::CloudController::V3::DeleteServiceBindingFactory).to receive(:for).and_return(actor)
        end

        it 'returns the actor resource type' do
          expect(subject.resource_type).to eq('super')
        end
      end
    end
  end
end
