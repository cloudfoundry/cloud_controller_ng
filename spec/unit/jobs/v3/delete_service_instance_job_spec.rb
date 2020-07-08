require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

RSpec.shared_examples 'service instance synchronous operations' do
  context 'when the broker responds with success' do
    before do
      allow(client).to receive(operation).and_return(broker_client_response)
      run_job(job, jobs_succeeded: 1)
    end

    it 'asks the client to execute the operation on the service instance' do
      expect(client).to have_received(operation).with(
        service_instance,
        accepts_incomplete: false,
      )
    end

    it 'completes the job' do
      pollable_job = VCAP::CloudController::PollableJobModel.last
      expect(pollable_job.resource_guid).to eq(service_instance.guid)
      expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
    end

    it 'creates an audit event' do
      event = VCAP::CloudController::Event.find(type: "audit.service_instance.#{operation_type}")
      expect(event).to be
      expect(event.actee).to eq(service_instance.guid)
    end

    it 'updates the database accordingly' do
      db_checks.call
    end
  end

  context 'when the broker client raises' do
    before do
      allow(client).to receive(operation).and_raise('Oh no')
    end

    it 'updates the instance status to delete failed' do
      run_job(job, jobs_succeeded: 0, jobs_failed: 1)

      service_instance.reload

      expect(service_instance.operation_in_progress?).to eq(false)
      expect(service_instance.terminal_state?).to eq(true)
      expect(service_instance.last_operation.type).to eq(operation_type)
      expect(service_instance.last_operation.state).to eq('failed')
    end

    it 'fails the pollable job' do
      pollable_job = run_job(job, jobs_succeeded: 0, jobs_failed: 1)
      pollable_job.reload
      expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
    end
  end
end

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      let(:broker_client_response) { {} }
      let(:operation) { :deprovision }
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
      let!(:service_instance) { ManagedServiceInstance.make }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
      let(:job) { described_class.new(service_instance.guid, operation, user_audit_info) }

      def run_job(job, jobs_succeeded: 2, jobs_failed: 0, jobs_to_execute: 100)
        pollable_job = Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue_pollable
        execute_all_jobs(expected_successes: jobs_succeeded, expected_failures: jobs_failed, jobs_to_execute: jobs_to_execute)
        pollable_job
      end

      before do
        allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
      end

      after do
        Timecop.return
      end

      context 'deprovisioning' do
        let(:operation) { :deprovision }
        let(:operation_type) { 'delete' }
        let(:broker_client_response) {
          { last_operation: { type: 'delete', state: 'succeeded' } }
        }
        let(:db_checks) do
          -> {
            expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
          }
        end

        it_behaves_like 'service instance synchronous operations'
      end
    end
  end
end
