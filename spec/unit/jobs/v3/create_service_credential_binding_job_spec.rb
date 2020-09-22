require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/create_service_credential_binding_job'

module VCAP::CloudController
  module V3
    RSpec.describe CreateServiceCredentialBindingJob do
      it_behaves_like 'delayed job', described_class

      let(:space) { Space.make }
      let(:service_instance) { ManagedServiceInstance.make(space: space) }
      let(:app_to_bind_to) { AppModel.make(space: space) }
      let(:state) { 'in progress' }
      let(:binding) do
        ServiceBinding.make(
          service_instance: service_instance,
          app: app_to_bind_to
        ).tap do |b|
          b.save_with_new_operation({
            type: 'create',
            state: state,
          })
        end
      end
      let(:user_info) { instance_double(Object) }
      let(:parameters) { { foo: 'bar' } }
      let(:subject) do
        described_class.new(
          binding.guid,
          parameters: parameters,
          user_audit_info: user_info,
        )
      end

      describe '#perform' do
        let(:action) do
          instance_double(V3::ServiceCredentialBindingCreate, {
            bind: nil,
          })
        end

        before do
          allow(V3::ServiceCredentialBindingCreate).to receive(:new).and_return(action)
        end

        context 'first time' do
          context 'synchronous response' do
            let(:state) { 'succeeded' }

            it 'calls bind and then finishes' do
              subject.perform

              expect(action).to have_received(:bind).with(
                binding,
                parameters: parameters,
                accepts_incomplete: false,
              )

              expect(subject.finished).to be_truthy
              expect(binding.reload.last_operation.state).to eq('succeeded')
              expect(binding.last_operation.type).to eq('create')
            end
          end

          context 'asynchronous response' do
            it 'calls bind and then fail the operation' do
              expect { subject.perform }.not_to raise_error

              expect(action).to have_received(:bind).with(
                binding,
                parameters: parameters,
                accepts_incomplete: false,
              )

              expect(subject.finished).to be_truthy
              expect(binding.reload.last_operation.state).to eq('failed')
              expect(binding.last_operation.type).to eq('create')
              expect(binding.last_operation.description).to eq('async bindings are not supported')
            end
          end
        end

        context 'binding not found' do
          it 'raises an API error' do
            binding.destroy

            expect { subject.perform }.to raise_error(
              CloudController::Errors::ApiError,
              /The binding could not be found/,
            )
          end
        end

        context 'bind fails' do
          it 'raises an API error' do
            allow(action).to receive(:bind).and_raise(StandardError)

            expect { subject.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'bind could not be completed: StandardError',
            )
          end
        end
      end

      describe '#operation' do
        it 'returns "bind"' do
          expect(subject.operation).to eq(:bind)
        end
      end

      describe '#operation_type' do
        it 'returns "create"' do
          expect(subject.operation_type).to eq('create')
        end
      end

      describe '#display_name' do
        it 'returns "service_bindings.create"' do
          expect(subject.display_name).to eq('service_bindings.create')
        end
      end

      describe '#resource_type' do
        it 'returns "service_binding"' do
          expect(subject.resource_type).to eq('service_binding')
        end
      end
    end
  end
end
