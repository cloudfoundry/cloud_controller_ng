require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/delete_service_instance_job'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/user_audit_info'
require 'services/service_brokers/v2/http_response'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      subject(:job) { described_class.new(service_instance.guid, user_audit_info) }

      let(:service_offering) { Service.make }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }

      describe '#perform' do
        let(:delete_response) { { finished: false, operation: 'test-operation' } }
        let(:poll_response) { { finished: false } }
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceDelete, {
            delete: delete_response,
            poll: poll_response
          })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceDelete).to receive(:new).and_return(action)
        end

        it 'passes the correct parameters to delete the action' do
          job.perform

          expect(VCAP::CloudController::V3::ServiceInstanceDelete).to have_received(:new).with(
            service_instance,
            an_instance_of(VCAP::CloudController::Repositories::ServiceEventRepository)
          ).at_least(:once)
        end

        context 'first time' do
          context 'synchronous response' do
            let(:delete_response) { { finished: true } }

            it 'calls delete and then finishes' do
              job.perform

              expect(action).to have_received(:delete)
              expect(job.finished).to be_truthy
            end

            it 'does not poll' do
              job.perform

              expect(action).not_to have_received(:poll)
            end
          end

          context 'asynchronous response' do
            let(:delete_response) { { finished: false } }

            context 'computes the maximum duration' do
              before do
                TestConfig.override({
                  broker_client_max_async_poll_duration_minutes: 90009
                })
                job.perform
              end

              it 'sets to the default value' do
                expect(job.maximum_duration_seconds).to eq(90009.minutes)
              end

              context 'when the plan defines a duration' do
                let(:maximum_polling_duration) { 7465 }
                let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }

                it 'sets to the plan value' do
                  expect(job.maximum_duration_seconds).to eq(7465)
                end
              end
            end

            it 'calls delete and then poll' do
              job.perform

              expect(action).to have_received(:delete)
              expect(action).to have_received(:poll)
              expect(job.finished).to be_falsey
            end
          end
        end

        context 'subsequent times' do
          before do
            service_instance.save_with_new_operation({}, {
              type: 'delete',
              state: 'in progress',
              broker_provided_operation: Sham.guid,
            })
          end

          it 'only calls poll' do
            job.perform

            expect(action).not_to have_received(:delete)
            expect(action).to have_received(:poll)
            expect(job.finished).to be_falsey
          end

          context 'poll indicates binding complete' do
            let(:poll_response) { { finished: true } }

            it 'finishes the job' do
              job.perform

              expect(job.finished).to be_truthy
            end
          end

          context 'the maximum duration' do
            it 'recomputes the value' do
              job.maximum_duration_seconds = 90009
              TestConfig.override({ broker_client_max_async_poll_duration_minutes: 8088 })
              job.perform
              expect(job.maximum_duration_seconds).to eq(8088.minutes)
            end

            context 'when the plan value changes between calls' do
              before do
                job.maximum_duration_seconds = 90009
                service_plan.update(maximum_polling_duration: 5000)
                job.perform
              end

              it 'sets to the new plan value' do
                expect(job.maximum_duration_seconds).to eq(5000)
              end
            end
          end
        end

        context 'retry interval' do
          def test_retry_after(value, expected)
            allow(action).to receive(:poll).and_return({ finished: false, retry_after: value })
            job.perform
            expect(job.polling_interval_seconds).to eq(expected)
          end

          it 'updates the polling interval' do
            test_retry_after(10, 60) # below default
            test_retry_after(65, 65)
            test_retry_after(1.hour, 1.hour)
            test_retry_after(25.hours, 24.hours) # above limit
          end
        end

        context 'service instance not found' do
          before do
            service_instance.destroy
          end

          it 'finishes the job' do
            job.perform

            expect(job.finished).to be_truthy
          end
        end

        context 'delete fails' do
          it 're-raises API errors' do
            allow(action).to receive(:delete).and_raise(
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name))

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              "An operation for service instance #{service_instance.name} is in progress.",
            )
          end

          it 'wraps other errors' do
            allow(action).to receive(:delete).and_raise(StandardError, 'bad thing')

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'delete could not be completed: bad thing',
            )
          end
        end

        context 'poll fails' do
          it 're-raises API errors' do
            allow(action).to receive(:poll).and_raise(
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name))

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              "An operation for service instance #{service_instance.name} is in progress.",
            )
          end

          it 'wraps other errors' do
            allow(action).to receive(:poll).and_raise(StandardError, 'bad thing')

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'delete could not be completed: bad thing',
            )
          end
        end
      end

      describe 'handle timeout' do
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceDelete, {
            update_last_operation_with_failure: nil,
          })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceDelete).to receive(:new).and_return(action)
        end

        it 'ask the action to update the last operation' do
          job.handle_timeout

          expect(action).to have_received(:update_last_operation_with_failure).with('Service Broker failed to deprovision within the required time.')
        end
      end

      describe '#operation' do
        it 'returns "deprovision"' do
          expect(job.operation).to eq(:deprovision)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(job.operation_type).to eq('delete')
        end
      end

      describe '#resource_type' do
        it 'returns "service_instances"' do
          expect(job.resource_type).to eq('service_instance')
        end
      end

      describe '#resource_guid' do
        it 'returns the service instance guid' do
          expect(job.resource_guid).to eq(service_instance.guid)
        end
      end

      describe '#display_name' do
        it 'returns the display name' do
          expect(job.display_name).to eq('service_instance.delete')
        end
      end
    end
  end
end
