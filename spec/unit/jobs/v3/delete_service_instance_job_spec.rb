require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      let(:service_offering) { Service.make }
      let(:service_plan) { ServicePlan.make(service: service_offering) }
      let(:service_instance) {
        ManagedServiceInstance.make(service_plan: service_plan)
      }

      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
      let(:subject) { described_class.new(service_instance.guid, user_audit_info) }
      let(:logger) { instance_double(Steno::Logger, error: nil, info: nil, warn: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      describe '#perform' do
        let(:client) { double('BrokerClient', deprovision: { instance: {}, last_operation: {} }) }

        before do
          allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
        end

        context 'when the client succeeds' do
          let(:r) do
            VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'all good')
          end

          before do
            allow(client).to receive(:deprovision).and_return(r)
          end

          it 'the pollable job state is set to polling' do
            subject.perform

            expect(subject.pollable_job_state).to eq(PollableJobModel::POLLING_STATE)
          end
        end

        context 'when there is a create operation in progress' do
          before do
            service_instance.save_with_new_operation({}, { type: 'create', state: 'in progress', description: 'barz' })
          end

          it 'attempts to delete anyways' do
            expect { subject.perform }.to_not raise_error
          end
        end

        context 'when the client raises a ServiceBrokerBadResponse' do
          let(:r) do
            VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'unexpected failure!')
          end

          let(:err) do
            VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, :delete, r)
          end

          before do
            allow(client).to receive(:deprovision).and_raise(err)
          end

          it 'restarts the job, as to perform orphan mitigation' do
            subject.perform

            expect(subject.instance_variable_get(:@attempts)).to eq(1)
            expect(subject.instance_variable_get(:@first_time)).to eq(true)
          end

          it 'the pollable job state is set to processing' do
            subject.perform

            expect(subject.pollable_job_state).to eq(PollableJobModel::PROCESSING_STATE)
          end

          it 'does not modify the service instance operation' do
            service_instance.save_with_new_operation(
              {},
              { type: 'create', state: 'done' }
            )

            subject.perform

            service_instance.reload

            expect(service_instance.last_operation.type).to eq('create')
            expect(service_instance.last_operation.state).to eq('done')
          end

          it 'logs a message' do
            subject.perform

            expect(logger).to have_received(:info).with(/Triggering orphan mitigation/)
          end

          it 'fails after too many retries' do
            number_of_successes = VCAP::CloudController::V3::ServiceInstanceAsyncJob::MAX_RETRIES - 1
            number_of_successes.times do
              subject.perform
            end

            expect { subject.perform }.to raise_error(CloudController::Errors::ApiError)
          end
        end

        context 'when the client raises an API Error' do
          before do
            allow(client).to receive(:deprovision).and_raise(err)
            service_instance.save_with_new_operation({}, {
              type: 'create',
              state: 'in progress',
              broker_provided_operation: 'some create operation'
            })
          end

          let(:err) do
            CloudController::Errors::ApiError.new_from_details('NotFound')
          end

          it 'fails the job and update the service instance last operation' do
            expect { subject.perform }.to raise_error(CloudController::Errors::ApiError, /Unknown request/)
            expect(subject.instance_variable_get(:@attempts)).to eq(0)

            service_instance.reload

            expect(service_instance.last_operation.type).to eq('delete')
            expect(service_instance.last_operation.state).to eq('failed')
          end

          context 'and the error name is AsyncServiceInstanceOperationInProgress' do
            let(:err) do
              CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'some name')
            end

            it 'fails the job but do not update the service instance last operation' do
              expect { subject.perform }.to raise_error(CloudController::Errors::ApiError, /create in progress/)
              expect(subject.instance_variable_get(:@attempts)).to eq(0)

              service_instance.reload

              expect(service_instance.last_operation.type).to eq('create')
              expect(service_instance.last_operation.state).to eq('in progress')
              expect(service_instance.last_operation.broker_provided_operation).to eq('some create operation')
            end
          end
        end

        context 'when the client raises a general error' do
          let(:err) { StandardError.new('random error') }

          before do
            allow(client).to receive(:deprovision).and_raise(err)
          end

          it 'fails the job' do
            expect { subject.perform }.to raise_error(err)
            expect(subject.instance_variable_get(:@attempts)).to eq(0)

            service_instance.reload

            expect(service_instance.last_operation.type).to eq('delete')
            expect(service_instance.last_operation.state).to eq('failed')
          end
        end
      end

      describe '#operation' do
        it 'returns "deprovision"' do
          expect(subject.operation).to eq(:deprovision)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(subject.operation_type).to eq('delete')
        end
      end

      describe '#send_broker_request' do
        let(:client) { double('BrokerClient', deprovision: 'some response') }

        it 'sends a deprovision request' do
          subject.send_broker_request(client)

          expect(client).to have_received(:deprovision).with(
            service_instance,
            accepts_incomplete: true,
          )
        end

        it 'returns the client response' do
          response = subject.send_broker_request(client)
          expect(response).to eq('some response')
        end

        it 'sets the @request_failed to false' do
          subject.send_broker_request(client)
          expect(subject.instance_variable_get(:@request_failed)).to eq(false)
        end

        context 'when the client raises a ServiceBrokerBadResponse' do
          it 'raises a DeprovisionBadResponse error' do
            r = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: '204', body: 'unexpected failure!')
            err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, :delete, r)
            allow(client).to receive(:deprovision).and_raise(err)

            expect { subject.send_broker_request(client) }.to raise_error(DeprovisionBadResponse, /unexpected failure!/)
          end
        end

        context 'when the client raises a AsyncServiceInstanceOperationInProgress' do
          it 'raises a DeprovisionBadResponse error' do
            err = CloudController::Errors::ApiError.new_from_details('AsyncServiceInstanceOperationInProgress', 'some instance name')
            allow(client).to receive(:deprovision).and_raise(err)

            expect { subject.send_broker_request(client) }.to raise_error(OperationAborted, /rejected the request/)
          end
        end

        context 'when the client raises an unknown error' do
          it 'raises the error' do
            allow(client).to receive(:deprovision).and_raise(RuntimeError.new('oh boy'))
            expect { subject.send_broker_request(client) }.to raise_error(RuntimeError, 'oh boy')
          end
        end
      end

      describe '#gone!' do
        it 'finishes the job' do
          job = DeleteServiceInstanceJob.new(service_instance.guid, user_audit_info)
          expect { job.gone! }.not_to raise_error
          expect(job.finished).to eq(true)
        end
      end

      describe '#operation_succeeded' do
        it 'deletes the service instance from the db' do
          expect(ManagedServiceInstance.first(guid: service_instance.guid)).not_to be_nil
          subject.operation_succeeded
          expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
        end
      end

      describe '#restart_on_failure?' do
        it 'returns true' do
          expect(subject.restart_on_failure?).to eq(true)
        end
      end
    end
  end
end
