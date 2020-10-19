require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/delete_route_binding_job'
require 'actions/service_route_binding_delete'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteRouteBindingJob do
      let(:subject) do
        described_class.new(
          binding.guid,
          user_audit_info: user_info
        )
      end

      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:maximum_polling_duration) { nil }
      let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
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

      it_behaves_like 'delayed job', described_class

      describe '#perform' do
        let(:delete_response) { nil }
        let(:poll_response) { { finished: false } }
        let(:action) do
          instance_double(V3::ServiceRouteBindingDelete, {
            delete: delete_response,
            poll: poll_response,
          })
        end

        before do
          allow(V3::ServiceRouteBindingDelete).to receive(:new).and_return(action)
        end

        context 'first time' do
          context 'synchronous response' do
            let(:delete_response) { V3::ServiceRouteBindingDelete::DeleteComplete.new }

            it 'calls delete and then finishes' do
              subject.perform

              expect(action).to have_received(:delete).with(
                binding,
                async_allowed: true,
              )

              expect(subject.finished).to be_truthy
            end

            it 'does not poll' do
              expect(action).not_to have_received(:poll)
            end
          end

          context 'asynchronous response' do
            let(:delete_response) { V3::ServiceRouteBindingDelete::DeleteStarted }

            context 'computes the maximum duration' do
              before do
                TestConfig.override({
                  broker_client_max_async_poll_duration_minutes: 90009
                })
                subject.perform
              end

              it 'sets to the default value' do
                expect(subject.maximum_duration_seconds).to eq(90009.minutes)
              end

              context 'when the plan defines a duration' do
                let(:maximum_polling_duration) { 7465 }

                it 'sets to the plan value' do
                  expect(subject.maximum_duration_seconds).to eq(7465)
                end
              end
            end

            it 'calls delete and then poll' do
              subject.perform

              expect(action).to have_received(:delete).with(
                binding,
                async_allowed: true,
              )

              expect(action).to have_received(:poll).with(binding)

              expect(subject.finished).to be_falsey
            end
          end
        end

        context 'subsequent times' do
          let(:new_action) do
            instance_double(V3::ServiceRouteBindingDelete, {
              delete: nil,
              poll: poll_response,
            })
          end

          before do
            subject.perform

            allow(V3::ServiceRouteBindingDelete).to receive(:new).and_return(new_action)
          end

          it 'only calls poll' do
            subject.perform

            expect(new_action).not_to have_received(:delete)
            expect(new_action).to have_received(:poll).with(binding)

            expect(subject.finished).to be_falsey
          end

          context 'poll indicates delete complete' do
            let(:poll_response) { { finished: true } }

            it 'finishes the job' do
              subject.perform

              expect(subject.finished).to be_truthy
            end
          end

          context 'the maximum duration' do
            it 'recomputes the value' do
              subject.maximum_duration_seconds = 90009
              TestConfig.override({ broker_client_max_async_poll_duration_minutes: 8088 })
              subject.perform
              expect(subject.maximum_duration_seconds).to eq(8088.minutes)
            end

            context 'when the plan value changes between calls' do
              before do
                subject.maximum_duration_seconds = 90009
                service_plan.update(maximum_polling_duration: 5000)
                subject.perform
              end

              it 'sets to the new plan value' do
                expect(subject.maximum_duration_seconds).to eq(5000)
              end
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

        context 'retry interval' do
          def test_retry_after(value, expected)
            allow(action).to receive(:poll).and_return({ finished: false, retry_after: value.to_s })
            subject.perform
            expect(subject.polling_interval_seconds).to eq(expected)
          end

          it 'updates the polling interval' do
            test_retry_after(10, 60) # below default
            test_retry_after(65, 65)
            test_retry_after(1.hour, 1.hour)
            test_retry_after(25.hours, 24.hours) # above limit
          end
        end

        context 'delete fails' do
          it 'raises an API error' do
            allow(action).to receive(:delete).and_raise(StandardError, 'bad thing')

            expect { subject.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'unbind could not be completed: bad thing',
            )

            binding.reload
            expect(binding.last_operation.type).to eq('delete')
            expect(binding.last_operation.state).to eq('failed')
          end
        end

        context 'poll fails' do
          it 'raises an API error' do
            allow(action).to receive(:poll).and_raise(StandardError, 'horrible')

            expect { subject.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'unbind could not be completed: horrible',
            )

            binding.reload
            expect(binding.last_operation.type).to eq('delete')
            expect(binding.last_operation.state).to eq('failed')
          end
        end
      end

      describe '#handle_timeout' do
        it 'updates the last operation to failed' do
          subject.handle_timeout

          binding.reload
          expect(binding.last_operation.type).to eq('delete')
          expect(binding.last_operation.state).to eq('failed')
          expect(binding.last_operation.description).to eq('Service Broker failed to unbind within the required time.')
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
    end
  end
end
