require 'spec_helper'

module VCAP::CloudController::Jobs
  RSpec.describe Enqueuer do
    let(:config_override) do
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
      TestConfig.override(config_override)
    end

    shared_examples_for 'a job enqueueing method' do
      let(:job_timeout) { rand(20).hours }
      let(:timeout_calculator) { instance_double(VCAP::CloudController::JobTimeoutCalculator) }

      before do
        expect(VCAP::CloudController::JobTimeoutCalculator).to receive(:new).with(TestConfig.config_instance).and_return(timeout_calculator)
        allow(timeout_calculator).to receive(:calculate).and_return(job_timeout)
      end

      it "populates LoggingContextJob's ID with the one from the thread-local Request" do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |logging_context_job, opts|
          expect(logging_context_job.request_id).to eq request_id
          original_enqueue.call(logging_context_job, opts)
        end

        ::VCAP::Request.current_id = request_id
        Enqueuer.new(wrapped_job, opts).public_send(method_name)
      end

      it 'uses the JobTimeoutCalculator' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job.handler).to be_a TimeoutJob
          expect(enqueued_job.handler.timeout).to eq(job_timeout)
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(wrapped_job, opts).public_send(method_name)
        expect(timeout_calculator).to have_received(:calculate).with(wrapped_job.job_name_in_configuration)
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
