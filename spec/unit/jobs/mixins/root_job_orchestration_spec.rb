require 'spec_helper'
require 'jobs/mixins/root_job_mixin'
require 'jobs/reoccurring_job'

# Integration-style: drives the real DelayedJob worker loop (+ Timecop) to prove root + sub-jobs converge.
module VCAP::CloudController
  module Jobs
    RSpec.describe 'RootJobMixin orchestration', isolation: :truncation do
      # Per-resource run counter, shared across ReoccurringJob's YAML reschedule and terminal-row deletion.
      RUN_COUNTS = Hash.new(0)

      # A sub-job that completes after `iterations` runs, or fails on run number `fail_on_run` (1-based).
      class CountingSubJob < ReoccurringJob
        def initialize(resource_guid, iterations: 1, fail_on_run: nil)
          super()
          @resource_guid = resource_guid
          @iterations = iterations
          @fail_on_run = fail_on_run
        end

        attr_reader :resource_guid

        def perform
          RUN_COUNTS[resource_guid] += 1
          run = RUN_COUNTS[resource_guid]
          raise CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'delete', "sub-job #{resource_guid} failed on run #{run}") if @fail_on_run == run

          finish if run >= @iterations
        end

        def display_name = "#{resource_guid}.delete"
        def resource_type = 'sub-resource'
        def max_attempts = 1
        def handle_timeout; end
      end

      # A root job mirroring the production body: defer while sub-jobs are in flight, else surface failure or finish.
      class CountingRootJob < ReoccurringJob
        include RootJobMixin

        attr_reader :resource_guid

        def initialize(resource_guid)
          super()
          @resource_guid = resource_guid
        end

        def perform
          perform_with_root_job_handling do
            RUN_COUNTS[resource_guid] += 1
            return if sub_jobs_in_flight?

            raise_if_sub_jobs_failed
            finish
          end
        end

        def display_name = 'root.delete'
        def resource_type = 'root-resource'
        def max_attempts = 1
        def handle_timeout; end

        def logger = Steno.logger('cc.jobs.test.root')
      end

      # Flat poll interval for every job so a single Timecop jump makes all rescheduled jobs due at once.
      let(:interval) { 60 }

      before do
        RUN_COUNTS.clear
        TestConfig.override(
          broker_client_default_async_poll_interval_seconds: interval,
          broker_client_async_poll_exponential_backoff_rate: 1.0,
          broker_client_max_async_poll_interval_seconds: interval + RootJobMixin::ROOT_JOB_BUFFER_SECONDS,
          broker_client_max_async_poll_duration_minutes: 24 * 60
        )
        Jobs::GenericEnqueuer.reset!
      end

      after do
        Jobs::GenericEnqueuer.reset!
        Timecop.return
      end

      # Enqueue the root, then each sub-job under the root's context (stamping root_job_guid on each row).
      def enqueue_root_with_sub_jobs(root, sub_jobs)
        Timecop.freeze do
          root_pollable = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(root)

          enqueuer = Jobs::GenericEnqueuer.shared
          enqueuer.activate_root_context(root_job_guid: root_pollable.guid)
          sub_jobs.each { |sj| enqueuer.enqueue_pollable(sj) }
          enqueuer.deactivate_root_context

          root_pollable
        end
      end

      # Runs the worker until nothing is due, advancing the clock one interval per pass; yields the root state each pass.
      def drain_until_settled(root_pollable, max_passes: 20)
        passes = 0
        max_passes.times do
          successes, failures = Delayed::Worker.new.work_off(100)
          break if successes.zero? && failures.zero?

          passes += 1
          yield(root_pollable.reload.state) if block_given?
          Timecop.freeze(Time.now + interval + RootJobMixin::ROOT_JOB_BUFFER_SECONDS + 1)
        end
        passes
      end

      def state_of(resource_guid)
        PollableJobModel.where(resource_guid:).first.state
      end

      context 'when sub-jobs take multiple runs and the root waits for all of them' do
        it 'reruns each occurrence until every sub-job completes, then completes the root, and never settles early' do
          root = CountingRootJob.new('root-1')
          root_pollable = enqueue_root_with_sub_jobs(root, [
            CountingSubJob.new('fast', iterations: 1),
            CountingSubJob.new('slow', iterations: 3)
          ])

          root_states = []
          passes = drain_until_settled(root_pollable) { |state| root_states << state }

          expect(state_of('fast')).to eq(PollableJobModel::COMPLETE_STATE)
          expect(state_of('slow')).to eq(PollableJobModel::COMPLETE_STATE)
          expect(root_pollable.reload.state).to eq(PollableJobModel::COMPLETE_STATE)

          # Root runs exactly as many times as the slowest sub-job (3) — no wasted trailing run.
          expect(RUN_COUNTS['fast']).to eq(1)
          expect(RUN_COUNTS['slow']).to eq(3)
          expect(passes).to eq(3)
          expect(RUN_COUNTS['root-1']).to eq(3)

          # Invariant: the root only reached COMPLETE on the final pass, never while a sub-job was active.
          expect(root_states[0...-1]).to all(eq(PollableJobModel::POLLING_STATE))
          expect(root_states.last).to eq(PollableJobModel::COMPLETE_STATE)
        end
      end

      context 'when one sub-job fails while another is still running' do
        it 'keeps deferring while the other sub-job is in flight, then fails the root once all have settled' do
          root = CountingRootJob.new('root-2')
          root_pollable = enqueue_root_with_sub_jobs(root, [
            CountingSubJob.new('failing', iterations: 5, fail_on_run: 1),
            CountingSubJob.new('running', iterations: 3)
          ])

          root_states = []
          passes = drain_until_settled(root_pollable) { |state| root_states << state }

          expect(state_of('failing')).to eq(PollableJobModel::FAILED_STATE)
          expect(state_of('running')).to eq(PollableJobModel::COMPLETE_STATE)
          expect(root_pollable.reload.state).to eq(PollableJobModel::FAILED_STATE)

          # Early failure adds no extra wakes: the root paces off the still-running sub-job (3 runs).
          expect(RUN_COUNTS['failing']).to eq(1)
          expect(RUN_COUNTS['running']).to eq(3)
          expect(passes).to eq(3)
          expect(RUN_COUNTS['root-2']).to eq(3)

          # The root kept polling until the still-running sub-job also settled, only then failing.
          expect(root_states[0...-1]).to all(eq(PollableJobModel::POLLING_STATE))
          expect(root_states.last).to eq(PollableJobModel::FAILED_STATE)
        end
      end

      context 'when a long-running sub-job fails only after several runs' do
        it 'defers across every occurrence until the sub-job eventually fails, then fails the root' do
          root = CountingRootJob.new('root-3')
          root_pollable = enqueue_root_with_sub_jobs(root, [
            CountingSubJob.new('eventual', iterations: 10, fail_on_run: 3)
          ])

          root_states = []
          passes = drain_until_settled(root_pollable) { |state| root_states << state }

          expect(state_of('eventual')).to eq(PollableJobModel::FAILED_STATE)
          expect(root_pollable.reload.state).to eq(PollableJobModel::FAILED_STATE)

          # Root runs exactly 3 times, no wasted trailing run after the failure settles.
          expect(RUN_COUNTS['eventual']).to eq(3)
          expect(passes).to eq(3)
          expect(RUN_COUNTS['root-3']).to eq(3)

          expect(root_states[0...-1]).to all(eq(PollableJobModel::POLLING_STATE))
          expect(root_states.last).to eq(PollableJobModel::FAILED_STATE)
        end
      end

      # next_execution_in makes the root pace off its sub-jobs' run_at instead of its own backoff.
      # First-tick caveat: the sub-job's run_at isn't committed yet, so the root takes one extra backoff wake.
      context 'when a sub-job polls slower than the root default backoff' do
        let(:sub_poll) { 120 }       # sub-job re-polls every 120s (e.g. a broker Retry-After)
        let(:root_backoff) { 30 }    # the root's default backoff would otherwise fire every 30s

        before do
          TestConfig.override(
            broker_client_default_async_poll_interval_seconds: root_backoff,
            broker_client_async_poll_exponential_backoff_rate: 1.0,
            broker_client_max_async_poll_interval_seconds: sub_poll + RootJobMixin::ROOT_JOB_BUFFER_SECONDS,
            broker_client_max_async_poll_duration_minutes: 24 * 60
          )
        end

        it 'collapses wasted wakes: runs far fewer times than the default backoff would' do
          root = CountingRootJob.new('root-4')
          slow_poller = CountingSubJob.new('slow-poller', iterations: 2)
          slow_poller.polling_interval_seconds = sub_poll

          root_pollable = enqueue_root_with_sub_jobs(root, [slow_poller])
          start = nil
          Timecop.freeze { start = Time.now }

          # Step in fine root_backoff increments so a root ignoring its sub-jobs' schedule could wake at every step.
          Timecop.freeze(start)
          total_span = (sub_poll * 2) + root_backoff
          steps = total_span / root_backoff
          steps.times do
            Delayed::Worker.new.work_off(100)
            break if root_pollable.reload.state != PollableJobModel::POLLING_STATE

            Timecop.freeze(Time.now + root_backoff)
          end

          expect(state_of('slow-poller')).to eq(PollableJobModel::COMPLETE_STATE)
          expect(root_pollable.reload.state).to eq(PollableJobModel::COMPLETE_STATE)
          expect(RUN_COUNTS['slow-poller']).to eq(2)

          # A bound, not an exact count: the precise number jitters by ±1 with DB-clock/worker interleaving.
          expect(RUN_COUNTS['root-4']).to be <= RUN_COUNTS['slow-poller'] + 1
          expect(RUN_COUNTS['root-4']).to be < steps / 2
        end
      end
    end
  end
end
