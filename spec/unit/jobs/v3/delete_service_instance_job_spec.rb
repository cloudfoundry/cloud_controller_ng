require 'spec_helper'
require 'jobs/v3/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceInstanceJob do
      it_behaves_like 'delayed job', described_class

      let(:broker_client_response) { {} }
      let(:operation) { :deprovision }
      let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
      let(:service_offering) { Service.make }
      let(:maximum_polling_duration) { nil }
      let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
      let(:service_instance) {
        si = ManagedServiceInstance.make(service_plan: service_plan)
        si.save_with_new_operation({}, { type: 'delete', state: 'in progress' })
        si.reload
      }

      let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'foo@example.com') }
      let(:job) { described_class.new(service_instance.guid, user_audit_info) }

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
        let(:db_checks) do
          -> {
            expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
          }
        end

        context 'when the broker responds synchronously' do
          it_behaves_like 'a one-off service instance job'
        end

        context 'asynchronous' do
          let(:broker_request_expect) { -> {
            expect(client).to have_received(operation).with(
              service_instance,
              accepts_incomplete: true
            )
          }
          }

          client_response = ->(broker_response) { broker_response }
          api_error_code = 10009

          it_behaves_like 'service instance reocurring job', 'delete', client_response, api_error_code
        end
      end
    end
  end
end
