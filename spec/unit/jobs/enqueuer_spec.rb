require 'spec_helper'
require 'db_spec_helper'
require 'jobs/enqueuer'
require 'jobs/delete_action_job'
require 'jobs/runtime/model_deletion'
require 'jobs/error_translator_job'

module VCAP::CloudController::Jobs
  RSpec.describe Enqueuer, job_context: :api do
    let(:config_override) do
      {
        jobs: {
          global: {
            timeout_in_seconds: global_timeout
          },
          queues: {},
          **priorities
        }
      }
    end
    let(:global_timeout) { 5.hours }
    let(:priorities) { {} }

    before do
      TestConfig.override(**config_override)
    end

    shared_examples_for 'a job enqueueing method' do
      let(:job_timeout) { rand(20).hours }
      let(:timeout_calculator) { instance_double(VCAP::CloudController::JobTimeoutCalculator) }

      before do
        expect(VCAP::CloudController::JobTimeoutCalculator).to receive(:new).with(TestConfig.config_instance).and_return(timeout_calculator)
        allow(timeout_calculator).to receive(:calculate).and_return(job_timeout)
      end

      after do
        ::VCAP::Request.current_id = nil
      end

      it "populates LoggingContextJob's ID with the one from the thread-local Request" do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |logging_context_job, opts|
          expect(logging_context_job.request_id).to eq request_id
          original_enqueue.call(logging_context_job, opts)
        end

        ::VCAP::Request.current_id = request_id
        Enqueuer.new(opts).public_send(method_name, wrapped_job)
      end

      it 'uses the JobTimeoutCalculator' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job.handler).to be_a TimeoutJob
          expect(enqueued_job.handler.timeout).to eq(job_timeout)
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(opts).public_send(method_name, wrapped_job)
        expect(timeout_calculator).to have_received(:calculate).with(wrapped_job.job_name_in_configuration, 'my-queue')
      end

      it 'uses the default priority' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(opts).not_to include(:priority)
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(opts).public_send(method_name, wrapped_job)
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
        Enqueuer.new(opts).enqueue(wrapped_job)
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
        Enqueuer.new(opts).enqueue_pollable(wrapped_job)
      end

      it 'returns the PollableJobModel' do
        result = Enqueuer.new(opts).enqueue_pollable(wrapped_job)
        latest_job = VCAP::CloudController::PollableJobModel.last
        expect(result).to eq(latest_job)
      end

      context 'when a block is given' do
        it 'wraps the pollable job with the result from the block' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(enqueued_job.handler.handler).to be_a ErrorTranslatorJob
            expect(enqueued_job.handler.handler.handler).to be_a PollableJobWrapper
            original_enqueue.call(enqueued_job, opts)
          end

          Enqueuer.new(opts).enqueue_pollable(wrapped_job) do |pollable_job|
            ErrorTranslatorJob.new(pollable_job)
          end
        end
      end

      it 'uses the default priority' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(opts).not_to include(:priority)
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(opts).enqueue_pollable(wrapped_job)
      end

      context 'priority from config' do
        context 'priority is configured via display_name' do
          let(:priorities) { { priorities: { 'object.delete': 1899, delete_action_job: 1900, 'VCAP::CloudController::Jobs::DeleteActionJob': 1901 } } }

          it 'uses the configured priority' do
            original_enqueue = Delayed::Job.method(:enqueue)
            expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
              expect(opts).to include({ priority: 1899 })
              original_enqueue.call(enqueued_job, opts)
            end
            Enqueuer.new(opts).enqueue_pollable(wrapped_job)
          end
        end

        context 'priority is configured via job_name_in_configuration' do
          let(:priorities) { { priorities: { delete_action_job: 1900, 'VCAP::CloudController::Jobs::DeleteActionJob': 1901 } } }

          it 'uses the configured priority' do
            original_enqueue = Delayed::Job.method(:enqueue)
            expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
              expect(opts).to include({ priority: 1900 })
              original_enqueue.call(enqueued_job, opts)
            end
            Enqueuer.new(opts).enqueue_pollable(wrapped_job)
          end
        end

        context 'priority is configured via class name' do
          let(:priorities) { { priorities: { 'VCAP::CloudController::Jobs::DeleteActionJob': 1901 } } }

          it 'uses the configured priority' do
            original_enqueue = Delayed::Job.method(:enqueue)
            expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
              expect(opts).to include({ priority: 1901 })
              original_enqueue.call(enqueued_job, opts)
            end
            Enqueuer.new(opts).enqueue_pollable(wrapped_job)
          end
        end

        context 'and priority from Enqueuer (e.g. from reoccurring jobs)' do
          it 'uses the priority passed into the Enqueuer' do
            original_enqueue = Delayed::Job.method(:enqueue)
            expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
              expect(opts).to include({ priority: 2000 })
              original_enqueue.call(enqueued_job, opts)
            end
            opts[:priority] = 2000
            Enqueuer.new(opts).enqueue_pollable(wrapped_job)
          end
        end
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
        Enqueuer.new(opts).run_inline(wrapped_job)
        expect(Delayed::Worker.delay_jobs).to be(true)
      end

      it 'uses the job timeout' do
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, _opts|
          expect(enqueued_job).to be_a TimeoutJob
          expect(enqueued_job.timeout).to eq(global_timeout)
        end
        Enqueuer.new(opts).run_inline(wrapped_job)
      end

      context 'when executing the job fails' do
        it 'still restores delay_jobs flag' do
          expect(Delayed::Job).to receive(:enqueue).and_raise('Boom!')
          expect(Delayed::Worker.delay_jobs).to be(true)
          expect do
            Enqueuer.new(opts).run_inline(wrapped_job)
          end.to raise_error(/Boom!/)
          expect(Delayed::Worker.delay_jobs).to be(true)
        end
      end
    end
  end
end
