require 'spec_helper'

module VCAP::CloudController
  module Jobs::Services
    RSpec.describe DeleteOrphanedInstance do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.new(service_plan: plan) }

      let(:name) { 'fake-name' }

      subject(:job) do
        VCAP::CloudController::Jobs::Services::DeleteOrphanedInstance.new(name, {},
          service_instance.guid, service_instance.service_plan.guid)
      end

      describe '#perform' do
        before do
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
        end

        it 'deprovisions the service instance with accepts_incomplete' do
          expect(client).to receive(:deprovision).with(service_instance, accepts_incomplete: true)
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq 0
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the name of the job' do
          expect(job.job_name_in_configuration).to eq(:delete_orphaned_instance)
        end
      end

      describe '#reschedule_at' do
        it 'uses exponential backoff' do
          now = Time.now
          attempts = 5

          run_at = job.reschedule_at(now, attempts)
          expect(run_at).to eq(now + (2**attempts).minutes)
        end
      end

      describe 'exponential backoff when the job fails' do
        def run_job
          expect(Delayed::Job.count).to eq 1
          execute_all_jobs(expected_successes: 0, expected_failures: 1)
        end

        it 'retries 10 times, doubling its back_off time with each attempt' do
          allow(client).to receive(:deprovision).and_raise(StandardError.new('I always fail'))
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)

          start = Delayed::Job.db_time_now
          opts = { queue: 'cc-generic', run_at: start }
          Jobs::Enqueuer.new(job, opts).enqueue

          run_at_time = start
          10.times do |i|
            Timecop.travel(run_at_time)
            run_job
            expect(Delayed::Job.first.run_at).to be_within(1.second).of(run_at_time + (2**(i + 1)).minutes)
            run_at_time = Delayed::Job.first.run_at
          end

          Timecop.travel(run_at_time)
          run_job
          execute_all_jobs(expected_successes: 0, expected_failures: 0) # not running any jobs

          expect(run_at_time).to be_within(1.minute).of(start + (2**11).minutes - 2.minutes)
        end
      end
    end
  end
end
