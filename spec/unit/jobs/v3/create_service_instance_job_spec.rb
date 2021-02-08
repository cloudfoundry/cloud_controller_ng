require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/user_audit_info'
require 'actions/v3/service_instance_create_managed'

module VCAP::CloudController
  module V3
    RSpec.describe CreateServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      it { expect(described_class).to be < VCAP::CloudController::Jobs::ReoccurringJob }

      let(:params) { { some_data: 'some_value' } }
      let(:maintenance_info) { { 'version' => '1.2.0' } }
      let(:plan) { ServicePlan.make(maintenance_info: maintenance_info) }
      let(:service_instance) do
        si = ManagedServiceInstance.make(service_plan: plan)
        si.save_with_new_operation(
          {},
          {
            type: 'create',
            state: 'in progress'
          }
        )
        si
      end
      let(:user_guid) { Sham.uaa_id }
      let(:user_info) { instance_double(UserAuditInfo, { user_guid: user_guid }) }
      let(:audit_hash) { { request: 'some_value' } }

      let(:job) {
        described_class.new(
          service_instance.guid,
          arbitrary_parameters: params,
          user_audit_info: user_info,
          audit_hash: audit_hash
        )
      }

      describe '#perform' do
        let(:provision_response) {}
        let(:poll_response) { { finished: false } }
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceCreateManaged, {
            provision: provision_response,
            poll: poll_response
          })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceCreateManaged).to receive(:new).and_return(action)
        end

        it 'passes the correct parameters to create the action' do
          job.perform

          expect(VCAP::CloudController::V3::ServiceInstanceCreateManaged).to have_received(:new).with(
            user_info,
            audit_hash
          ).at_least(:once)
        end

        it 'raises if the service instance no longer exists' do
          service_instance.destroy

          expect { job.perform }.to raise_error(
            CloudController::Errors::ApiError,
            /The service instance could not be found: #{service_instance.guid}./,
          )
        end

        context 'when there is another operation in progress' do
          before do
            service_instance.save_with_new_operation({}, { type: 'some-other-operation', state: 'in progress', description: 'barz' })
          end

          it 'raises an error' do
            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              /create could not be completed: some-other-operation in progress/
            )

            service_instance.reload
            expect(service_instance.last_operation.type).to eq('some-other-operation')
            expect(service_instance.last_operation.state).to eq('in progress')
            expect(service_instance.last_operation.description).to eq('barz')
          end
        end

        context 'first time' do
          context 'runs compatibility checks' do
            context 'volume mount' do
              let(:service_offering) { Service.make(requires: %w(volume_mount)) }
              let(:plan) { ServicePlan.make(service: service_offering) }

              it 'adds to the warnings required but disabled' do
                TestConfig.config[:volume_services_enabled] = false
                job.perform
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::VOLUME_SERVICE_WARNING)
              end

              it 'does not warn if enabled' do
                TestConfig.config[:volume_services_enabled] = true
                job.perform
                expect(job.warnings).to be_empty
              end
            end

            context 'route forwarding' do
              let(:service_offering) { Service.make(requires: %w(route_forwarding)) }
              let(:plan) { ServicePlan.make(service: service_offering) }

              it 'adds to the warnings required but disabled' do
                TestConfig.config[:route_services_enabled] = false
                job.perform
                expect(job.warnings.to_json).to include(VCAP::CloudController::ServiceInstance::ROUTE_SERVICE_WARNING)
              end

              it 'does not warn if enabled' do
                TestConfig.config[:route_services_enabled] = true
                job.perform
                expect(job.warnings).to be_empty
              end
            end
          end

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
              let(:plan) { ServicePlan.make(maximum_polling_duration: maximum_polling_duration) }

              it 'sets to the plan value' do
                expect(job.maximum_duration_seconds).to eq(7465)
              end
            end
          end

          context 'synchronous response' do
            before do
              service_instance.save_with_new_operation({}, { type: 'create', state: 'succeeded' })
            end

            it 'calls provision and then finishes' do
              job.perform

              expect(action).to have_received(:provision).with(
                service_instance,
                parameters: params,
                accepts_incomplete: true,
              )

              expect(job.finished).to be_truthy
            end

            it 'does not poll' do
              job.perform

              expect(action).not_to have_received(:poll)
            end
          end

          context 'asynchronous response' do
            it 'calls provision and then poll' do
              job.perform

              expect(action).to have_received(:provision).with(
                service_instance,
                parameters: params,
                accepts_incomplete: true,
              )

              expect(action).to have_received(:poll).with(service_instance)

              expect(job.finished).to be_falsey
            end
          end

          context 'provision fails' do
            it 'raises an API error' do
              allow(action).to receive(:provision).and_raise(StandardError)

              expect { job.perform }.to raise_error(
                CloudController::Errors::ApiError,
                'provision could not be completed: StandardError',
              )

              service_instance.reload
              expect(service_instance.last_operation.type).to eq('create')
              expect(service_instance.last_operation.state).to eq('failed')
              expect(service_instance.last_operation.description).to eq('StandardError')
            end
          end
        end

        context 'subsequent times' do
          before do
            service_instance.save_with_new_operation({}, {
              type: 'create',
              state: 'in progress',
              broker_provided_operation: Sham.guid,
            })
            job.perform
          end

          it 'only calls poll' do
            job.perform

            expect(action).to have_received(:provision).once
            expect(action).to have_received(:poll).twice
            expect(job.finished).to be_falsey
          end

          context 'poll indicates provision complete' do
            let(:poll_response) { { finished: true } }

            it 'finishes the job' do
              job.perform

              expect(job.finished).to be_truthy
            end
          end

          context 'when retry_after is returned in the broker response' do
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
                plan.update(maximum_polling_duration: 5000)

                job.perform
              end

              it 'sets to the new plan value' do
                expect(job.maximum_duration_seconds).to eq(5000)
              end
            end
          end
        end

        context 'poll fails' do
          it 're-raises LastOperationFailedState errors' do
            allow(action).to receive(:poll).and_raise(
              VCAP::CloudController::V3::ServiceInstanceCreateManaged::LastOperationFailedState.new('Something went wrong')
            )

            expect { job.perform }.to raise_error(
              VCAP::CloudController::V3::ServiceInstanceCreateManaged::LastOperationFailedState,
              'Something went wrong',
            )
          end

          it 're-raises API errors' do
            allow(action).to receive(:poll).and_raise(
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', service_instance.name)
            )

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              "An operation for service instance #{service_instance.name} is in progress.",
            )
          end

          it 'wraps other errors' do
            allow(action).to receive(:poll).and_raise(StandardError, 'bad thing')

            expect { job.perform }.to raise_error(
              CloudController::Errors::ApiError,
              'provision could not be completed: bad thing',
            )
          end
        end
      end

      describe '#handle_timeout' do
        it 'updates the service instance last operation' do
          job.handle_timeout

          service_instance.reload

          expect(service_instance.last_operation.type).to eq('create')
          expect(service_instance.last_operation.state).to eq('failed')
          expect(service_instance.last_operation.description).to eq('Service Broker failed to provision within the required time.')
        end
      end

      describe '#operation' do
        it 'returns "provision"' do
          expect(job.operation).to eq(:provision)
        end
      end

      describe '#operation_type' do
        it 'returns "create"' do
          expect(job.operation_type).to eq('create')
        end
      end

      describe '#resource_type' do
        it 'returns "service_instances"' do
          expect(job.resource_type).to eq('service_instances')
        end
      end

      describe '#resource_guid' do
        it 'returns the service instance guid' do
          expect(job.resource_guid).to eq(service_instance.guid)
        end
      end

      describe '#display_name' do
        it 'returns the display name' do
          expect(job.display_name).to eq('service_instance.create')
        end
      end
    end
  end
end
