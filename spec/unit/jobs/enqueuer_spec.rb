require 'spec_helper'
require 'db_spec_helper'
require 'jobs/enqueuer'
require 'jobs/delete_action_job'
require 'jobs/runtime/model_deletion'
require 'jobs/error_translator_job'
require 'jobs/v3/recursive_delete_app_job'

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

      context 'when run_at is provided' do
        it 'enqueues the job with the specified run_at time' do
          original_enqueue = Delayed::Job.method(:enqueue)
          wrapped_job = Runtime::ModelDeletion.new('one', 'two')
          future_time = Time.now + 1.month
          expect(Delayed::Job).to(receive(:enqueue)) do |enqueued_job, opts|
            expect(opts[:run_at]).to eq(future_time)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new({ queue: 'my-queue', run_at: Time.now + 1.hour }).enqueue(wrapped_job, run_at: future_time)
        end
      end

      context 'when priority_increment is provided' do
        it 'adds the priority_increment to the base priority' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(17)
            original_enqueue.call(enqueued_job, opts)
          end
          opts[:priority] = 10
          Enqueuer.new(opts).enqueue(wrapped_job, priority_increment: 7)
        end
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

      context 'when run_at is provided' do
        it 'enqueues the job with the specified run_at time' do
          future_time = Time.now + 1.month
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to(receive(:enqueue)) do |enqueued_job, opts|
            expect(opts[:run_at]).to eq(future_time)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, run_at: future_time)
        end
      end

      context 'when priority_increment is provided' do
        it 'enqueues the job with the specified priority_increment' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(3)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, priority_increment: 3)
        end

        it 'adds the priority_increment to the base priority' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(17)
            original_enqueue.call(enqueued_job, opts)
          end
          opts[:priority] = 10
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, priority_increment: 7)
        end

        it 'ignores negative priority_increment values' do
          original_enqueue = Delayed::Job.method(:enqueue)
          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(3)
            original_enqueue.call(enqueued_job, opts)
          end
          opts[:priority] = 3
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, priority_increment: -8)
        end

        it 'adds the priority_increment to the configured priority' do
          original_enqueue = Delayed::Job.method(:enqueue)
          allow_any_instance_of(Enqueuer).to receive(:get_overwritten_job_priority_from_config).and_return(1899)

          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(1903)
            original_enqueue.call(enqueued_job, opts)
          end
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, priority_increment: 4)
        end
      end

      context 'when preserve_priority is true' do
        it 'does not modify the priority even if a configured priority is present or a priority_increment is provided' do
          original_enqueue = Delayed::Job.method(:enqueue)
          allow_any_instance_of(Enqueuer).to receive(:get_overwritten_job_priority_from_config).and_return(1899)

          expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
            expect(opts[:priority]).to eq(1901)
            original_enqueue.call(enqueued_job, opts)
          end
          opts[:priority] = 1901
          Enqueuer.new(opts).enqueue_pollable(wrapped_job, preserve_priority: true, priority_increment: 4)
        end
      end
    end

    describe '#enqueue_or_find_active_pollable' do
      let(:app_model) { create(:app_model) }
      let(:user_audit_info) { VCAP::CloudController::UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'test@example.com') }
      let(:job_factory) { ->(_resource) { VCAP::CloudController::V3::RecursiveDeleteAppJob.new(app_model.guid, user_audit_info) } }

      def enqueue
        Enqueuer.new(queue: Queues.generic).enqueue_or_find_active_pollable(
          resource_model: VCAP::CloudController::AppModel, resource_guid: app_model.guid, operation: 'app.delete', &job_factory
        )
      end

      context 'when no active delete job exists for the resource' do
        it 'creates a new pollable job and returns it' do
          job = nil
          expect { job = enqueue }.to change(VCAP::CloudController::PollableJobModel, :count).by(1)

          expect(job).to be_a(VCAP::CloudController::PollableJobModel)
          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::PROCESSING_STATE)
          expect(job.operation).to eq('app.delete')
          expect(job.resource_guid).to eq(app_model.guid)
        end
      end

      context 'when an active delete job already exists for the resource' do
        let!(:existing) do
          create(:pollable_job_model,
                 state: VCAP::CloudController::PollableJobModel::PROCESSING_STATE,
                 resource_guid: app_model.guid,
                 operation: 'app.delete')
        end

        it 'returns the existing pollable job without enqueueing a new one' do
          result = nil
          expect { result = enqueue }.not_to change(VCAP::CloudController::PollableJobModel, :count)

          expect(result.guid).to eq(existing.guid)
        end

        it 'does not invoke the job factory block' do
          invoked = false
          Enqueuer.new(queue: Queues.generic).enqueue_or_find_active_pollable(
            resource_model: VCAP::CloudController::AppModel, resource_guid: app_model.guid, operation: 'app.delete'
          ) do |_resource|
            invoked = true
            VCAP::CloudController::V3::RecursiveDeleteAppJob.new(app_model.guid, user_audit_info)
          end

          expect(invoked).to be(false)
        end
      end

      context 'when the resource no longer exists' do
        before { app_model.destroy }

        it 'returns nil and does not enqueue a job' do
          result = nil
          expect { result = enqueue }.not_to change(VCAP::CloudController::PollableJobModel, :count)
          expect(result).to be_nil
        end
      end

      context 'row lock' do
        it 'builds a SELECT ... FOR UPDATE query on the resource row' do
          sql = VCAP::CloudController::AppModel.where(guid: app_model.guid).for_update.sql
          expect(sql).to match(/FOR UPDATE/i)
        end
      end
    end
  end
end
