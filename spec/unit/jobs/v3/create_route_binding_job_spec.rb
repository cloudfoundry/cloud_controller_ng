require 'spec_helper'
require 'jobs/v3/create_route_binding_job'

module VCAP::CloudController
  module V3
    RSpec.describe CreateRouteBindingJob do
      it_behaves_like 'delayed job', described_class

      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan, space: space) }
      let(:route) { Route.make(space: space) }
      let(:state) { 'in progress' }
      let(:binding) do
        RouteBinding.new.save_with_new_operation(
          {
            service_instance: service_instance,
            route: route,
          },
          {
            type: 'create',
            state: state,
          },
        )
      end
      let(:user_info) { instance_double(Object) }
      let(:parameters) { { foo: 'bar' } }
      let(:subject) do
        described_class.new(
          binding.guid,
          parameters: parameters,
          user_audit_info: user_info
        )
      end

      describe '#perform' do
        let(:poll_response) { false }
        let(:action) do
          instance_double(V3::ServiceRouteBindingCreate, {
            bind: nil,
            poll: poll_response,
          })
        end

        before do
          allow(V3::ServiceRouteBindingCreate).to receive(:new).and_return(action)
        end

        context 'binding not found' do
          it 'raises' do
            binding.destroy

            expect { subject.perform }.to raise_error(
              CloudController::Errors::ApiError,
              /The binding could not be found/,
            )
          end
        end

        context 'first time' do
          context 'synchronous response' do
            let(:state) { 'succeeded' }

            it 'calls bind and then finishes' do
              subject.perform

              expect(action).to have_received(:bind).with(
                binding,
                parameters: parameters,
                accepts_incomplete: true,
              )

              expect(subject.finished).to be_truthy
            end
          end

          context 'asynchronous response' do
            it 'calls bind and then poll' do
              subject.perform

              expect(action).to have_received(:bind).with(
                binding,
                parameters: parameters,
                accepts_incomplete: true,
              )

              expect(action).to have_received(:poll).with(binding)

              expect(subject.finished).to be_falsey
            end
          end
        end

        context 'subsequent times' do
          let(:new_action) do
            instance_double(V3::ServiceRouteBindingCreate, {
              bind: nil,
              poll: poll_response,
            })
          end

          before do
            subject.perform

            allow(V3::ServiceRouteBindingCreate).to receive(:new).and_return(new_action)
          end

          it 'only calls poll' do
            subject.perform

            expect(new_action).not_to have_received(:bind)
            expect(new_action).to have_received(:poll).with(binding)

            expect(subject.finished).to be_falsey
          end

          context 'poll indicates binding complete' do
            let(:poll_response) { true }

            it 'finishes the job' do
              subject.perform

              expect(subject.finished).to be_truthy
            end
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
    end
  end
end
