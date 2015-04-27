require 'spec_helper'

module VCAP::CloudController
  module Jobs::Services
    describe DeleteOrphanedKey do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
      let(:service_instance_guid) { 'fake-instance-guid' }
      let(:key_guid) { 'fake-key-guid' }

      let(:service_key) { instance_double('VCAP::CloudController::ServiceKey') }
      before do
        allow(VCAP::CloudController::ServiceKey).to receive(:new).and_return(service_key)
      end

      let(:name) { 'fake-name' }
      subject(:job) { VCAP::CloudController::Jobs::Services::DeleteOrphanedKey.new(name, {}, key_guid, service_instance_guid) }

      describe '#perform' do
        before do
          allow(client).to receive(:unbind).with(service_key)
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
        end

        it 'deletes the key' do
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          expect(Delayed::Worker.new.work_off).to eq [1, 0]

          expect(client).to have_received(:unbind).with(service_key)
        end
      end

      describe '#job_name_in_configuration' do
        it 'returns the name of the job' do
          expect(job.job_name_in_configuration).to eq(:delete_orphaned_key)
        end
      end

      describe '#reschedule_at' do
        it 'uses exponential backoff' do
          now = Time.now

          run_at = job.reschedule_at(now, 5)
          expect(run_at).to eq(now + (2**5).minutes)
        end
      end

      describe 'exponential backoff when the job fails' do
        def run_job
          expect(Delayed::Job.count).to eq 1
          expect(Delayed::Worker.new.work_off).to eq [0, 1]
        end

        it 'retries 10 times, doubling its back_off time with each attempt' do
          allow(client).to receive(:unbind).and_raise(StandardError.new('I always fail'))
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
          expect(Delayed::Worker.new.work_off).to eq [0, 0] # not running any jobs

          expect(run_at_time).to be_within(1.minute).of(start + (2**11).minutes - 2.minutes)
        end
      end
    end
  end
end
