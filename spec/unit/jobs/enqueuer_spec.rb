require 'spec_helper'

module VCAP::CloudController::Jobs
  RSpec.describe Enqueuer do
    let(:config) do
      {
        jobs: {
          global: {
            timeout_in_seconds: global_timeout,
          }
        }
      }
    end
    let(:global_timeout) { 5.hours }

    before do
      allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
    end

    shared_examples_for 'a job enqueueing method' do
      it "populates LoggingContextJob's ID with the one from the thread-local Request" do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |logging_context_job, opts|
          expect(logging_context_job.request_id).to eq request_id
          original_enqueue.call(logging_context_job, opts)
        end

        ::VCAP::Request.current_id = request_id
        Enqueuer.new(wrapped_job, opts).public_send(method_name)
      end

      context 'when the config has a timeout defined for the given job' do
        let(:config) do
          {
            jobs: {
              "#{wrapped_job.job_name_in_configuration}": {
                timeout_in_seconds: job_timeout,
              }
            }
          }
        end
        let(:job_timeout) { 2.hours }

        it 'uses the job timeout' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(enqueued_job.handler).to be_a TimeoutJob
            expect(enqueued_job.handler.timeout).to eq(job_timeout)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new(wrapped_job, opts).public_send(method_name)
        end
      end

      context 'when the job does NOT implement job_name_in_configuration' do
        before do
          wrapped_job.instance_eval do
            undef :job_name_in_configuration
          end
        end

        it 'uses the job timeout' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(enqueued_job.handler).to be_a TimeoutJob
            expect(enqueued_job.handler.timeout).to eq(global_timeout)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new(wrapped_job, opts).public_send(method_name)
        end
      end
    end

    describe '#enqueue' do
      let(:wrapped_job) { Runtime::ModelDeletion.new('one', 'two') }
      let(:opts) { { queue: 'my-queue' } }
      let(:request_id) { 'abc123' }

      it_behaves_like 'a job enqueueing method' do
        let(:method_name) { 'enqueue' }
      end

      it 'delegates to Delayed::Job' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job).to be_a LoggingContextJob
          expect(enqueued_job.handler).to be_a TimeoutJob
          expect(enqueued_job.handler.timeout).to eq(global_timeout)
          expect(enqueued_job.handler.handler).to be wrapped_job
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(wrapped_job, opts).enqueue
      end
    end

    describe '#enqueue_pollable' do
      let(:wrapped_job) { DeleteActionJob.new(Object, 'guid', double) }
      let(:opts) { { queue: 'my-queue' } }
      let(:request_id) { 'abc123' }

      it_behaves_like 'a job enqueueing method' do
        let(:method_name) { 'enqueue_pollable' }
      end

      it 'enqueues as a PollableJob' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job).to be_a LoggingContextJob
          expect(enqueued_job.handler).to be_a TimeoutJob
          expect(enqueued_job.handler.timeout).to eq(global_timeout)
          expect(enqueued_job.handler.handler).to be_a PollableJobWrapper
          expect(enqueued_job.handler.handler.handler).to be wrapped_job
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(wrapped_job, opts).enqueue_pollable
      end

      it 'returns the PollableJobModel' do
        # pollable_job_model = instance_double(VCAP::CloudController::PollableJobModel)
        # expect(VCAP::CloudController::PollableJobModel).to receive(:create).and_return(pollable_job_model)
        result = Enqueuer.new(wrapped_job, opts).enqueue_pollable
        latest_job = VCAP::CloudController::PollableJobModel.last
        expect(result).to eq(latest_job)
      end
    end

    describe '#run_inline' do
      let(:wrapped_job) { Runtime::ModelDeletion.new('one', 'two') }
      let(:opts) { {} }

      it 'schedules the job to run immediately in-process' do
        expect(Delayed::Job).to receive(:enqueue) do
          expect(Delayed::Worker.delay_jobs).to be(false)
        end

        expect(Delayed::Worker.delay_jobs).to be(true)
        Enqueuer.new(wrapped_job, opts).run_inline
        expect(Delayed::Worker.delay_jobs).to be(true)
      end

      it 'uses the job timeout' do
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job).to be_a TimeoutJob
          expect(enqueued_job.timeout).to eq(global_timeout)
        end
        Enqueuer.new(wrapped_job, opts).run_inline
      end

      context 'when executing the job fails' do
        it 'still restores delay_jobs flag' do
          expect(Delayed::Job).to receive(:enqueue).and_raise('Boom!')
          expect(Delayed::Worker.delay_jobs).to be(true)
          expect {
            Enqueuer.new(wrapped_job, opts).run_inline
          }.to raise_error(/Boom!/)
          expect(Delayed::Worker.delay_jobs).to be(true)
        end
      end
    end
  end
end
