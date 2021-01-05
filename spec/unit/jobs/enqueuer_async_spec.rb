require 'db_spec_helper'
require 'jobs/enqueuer'
require 'jobs/delete_action_job'
require 'jobs/runtime/model_deletion'
require 'jobs/error_translator_job'

# DelayedJob Plugin additions for collecting data within callbacks
class TestDelayedPlugin < Delayed::Plugin
  # rubocop:disable Style/ClassVars
  @@callback_state = {}
  # rubocop:enable Style/ClassVars

  def self.callback_counts
    @@callback_state
  end

  def self.callback_state(phase)
    case phase
    when :before_before, :after_before
      callbacks do |lifecycle|
        lifecycle.before(:enqueue) do
          collect_counts(phase)
        end
      end
    when :before_after
      callbacks do |lifecycle|
        lifecycle.after(:enqueue) do
          collect_counts(phase)
        end
      end
    end
  end

  def self.collect_counts(phase)
    @@callback_state[phase] = {}
    @@callback_state[phase][:last_pollable_count] = VCAP::CloudController::PollableJobModel.count
    @@callback_state[phase][:delayed_job_count] = Delayed::Job.count
  end
end

class BeforeBeforeEnqueueHook < TestDelayedPlugin
  callback_state(:before_before)
end

class AfterBeforeEnqueueHook < TestDelayedPlugin
  callback_state(:after_before)
end

class BeforeAfterEnqueueHook < TestDelayedPlugin
  callback_state(:before_after)
end

# Spec for validating async order of operations for pollable job and delayed job
module VCAP::CloudController::Jobs
  RSpec.describe Enqueuer, job_context: :api do
    describe '#enqueue_pollable' do
      let(:wrapped_job) { DeleteActionJob.new(Object, 'guid', double) }
      let(:opts) { { queue: 'my-queue' } }
      let(:request_id) { 'abc123' }

      it 'creates PollableJobModel via callback before enqueing Delayed::Job' do
        dj_plugins = Delayed::Worker.plugins.dup

        Delayed::Worker.plugins.delete(AfterEnqueueHook)
        Delayed::Worker.plugins.delete(BeforeEnqueueHook)
        Delayed::Worker.plugins << BeforeBeforeEnqueueHook # Collecting state via callback
        Delayed::Worker.plugins << BeforeEnqueueHook
        Delayed::Worker.plugins << AfterBeforeEnqueueHook  # Collecting state via callback
        Delayed::Worker.plugins << BeforeAfterEnqueueHook  # Collecting state via callback
        Delayed::Worker.plugins << AfterEnqueueHook

        Enqueuer.new(wrapped_job, opts).enqueue_pollable
        job_state = TestDelayedPlugin.callback_counts

        # We are testing an asynchronous event to verify that the PollableJobModel is updated before DelayedJob
        expected_state = {
          # We expect that PollableJobs and DelayedJob is empty to start
          before_before: { last_pollable_count: 0, delayed_job_count: 0 },
          # We expect the PollableJobModel to have an entry before DelayedJob
          after_before: { last_pollable_count: 1, delayed_job_count: 0 },
          # We expect both PollableJobModel and DelayedJob to have a record before the after callback
          before_after: { last_pollable_count: 1, delayed_job_count: 1 }
        }

        expect(job_state).to eq(expected_state)

        Delayed::Worker.plugins = dj_plugins.dup
      end
    end
  end
end
