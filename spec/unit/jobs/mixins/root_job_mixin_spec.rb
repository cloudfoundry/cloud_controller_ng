require 'spec_helper'
require 'jobs/mixins/root_job_mixin'
require 'jobs/reoccurring_job'
require 'jobs/v3/recursive_delete_app_job'

module VCAP::CloudController
  module Jobs
    RSpec.describe RootJobMixin do
      let(:test_job_class) do
        Class.new(ReoccurringJob) do
          include RootJobMixin

          attr_reader :resource_guid

          def initialize(resource_guid)
            super()
            @resource_guid = resource_guid
          end

          def perform; end

          def display_name
            'test.delete'
          end

          def resource_type
            'test'
          end

          def max_attempts
            1
          end

          def logger
            Steno.logger('cc.jobs.test')
          end
        end
      end

      let(:job) { test_job_class.new('resource-guid-1') }

      before { Jobs::GenericEnqueuer.reset! }
      after { Jobs::GenericEnqueuer.reset! }

      def make_root(state: PollableJobModel::PROCESSING_STATE)
        create(:pollable_job_model, state: state, resource_guid: 'resource-guid-1', operation: 'test.delete')
      end

      def make_sub_job(state:, **attrs)
        create(:pollable_job_model, root_job_guid: root_pollable_job.guid, state: state, **attrs)
      end

      describe '#next_execution_in' do
        let(:max_interval) { 100 }

        before do
          allow(Config.config).to receive(:get).and_call_original
          allow(Config.config).to receive(:get).with(:broker_client_max_async_poll_interval_seconds).and_return(max_interval)
        end

        context 'when an active sub-job is due later' do
          before { allow(job).to receive(:seconds_until_slowest_sub_job).and_return(30) }

          it 'wakes after that many seconds, plus the buffer' do
            expect(job.send(:next_execution_in)).to eq(30 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)
          end

          it 'caps the interval at the max async poll interval' do
            allow(job).to receive(:seconds_until_slowest_sub_job).and_return(9999)
            expect(job.send(:next_execution_in)).to eq(max_interval)
          end
        end

        context 'when no sub-job is due in the future' do
          before { allow(job).to receive(:seconds_until_slowest_sub_job).and_return(nil) }

          it 'falls back to the ReoccurringJob interval plus the buffer' do
            allow(job).to receive(:polling_interval_seconds).and_return(80)
            expect(job.send(:next_execution_in)).to eq(80 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)
          end
        end

        context 'across occurrences with real sub-job rows' do
          let!(:root_pollable_job) { make_root }
          let(:now) { Delayed::Job.db_time_now }

          def add_active_sub_job(run_at:, state: PollableJobModel::POLLING_STATE)
            dj = Delayed::Job.create!(guid: SecureRandom.uuid, handler: 'fake', run_at: run_at, queue: 'cc-generic')
            create(:pollable_job_model, root_job_guid: root_pollable_job.guid, state: state, delayed_job_guid: dj.guid)
            dj
          end

          it 'derives the interval from the latest run_at among multiple active sub-jobs' do
            add_active_sub_job(run_at: now + 10)
            add_active_sub_job(run_at: now + 40)
            add_active_sub_job(run_at: now + 25)

            expect(job.send(:next_execution_in)).to be_within(1).of(40 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)
          end

          it 'ignores completed and failed sub-job rows, pacing only off the active ones' do
            add_active_sub_job(run_at: now + 20)
            add_active_sub_job(run_at: now + 90, state: PollableJobModel::COMPLETE_STATE)
            add_active_sub_job(run_at: now + 90, state: PollableJobModel::FAILED_STATE)

            expect(job.send(:next_execution_in)).to be_within(1).of(20 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)
          end

          it 're-derives from fresh rows when a sub-job re-enqueues' do
            first = add_active_sub_job(run_at: now + 15)
            expect(job.send(:next_execution_in)).to be_within(1).of(15 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)

            # next_execution_in reads sub-jobs directly, so it tracks the fresh row, not the destroyed one.
            first.destroy
            PollableJobModel.where(delayed_job_guid: first.guid).delete
            add_active_sub_job(run_at: now + 55)

            expect(job.send(:next_execution_in)).to be_within(1).of(55 + RootJobMixin::ROOT_JOB_BUFFER_SECONDS)
          end
        end
      end

      describe '#active_sub_jobs' do
        let!(:root_pollable_job) { make_root }

        it 'returns only the active (processing/polling) sub-jobs' do
          make_sub_job(state: PollableJobModel::PROCESSING_STATE, delayed_job_guid: 'active-1')
          make_sub_job(state: PollableJobModel::POLLING_STATE, delayed_job_guid: 'active-2')
          make_sub_job(state: PollableJobModel::COMPLETE_STATE, delayed_job_guid: 'done-1')
          make_sub_job(state: PollableJobModel::FAILED_STATE, delayed_job_guid: 'failed-1')
          job.send(:fetch_root_context)

          expect(job.send(:active_sub_jobs).map(&:delayed_job_guid)).to contain_exactly('active-1', 'active-2')
        end

        it 'returns empty when there is no active root job' do
          root_pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
          job.send(:fetch_root_context)
          expect(job.send(:active_sub_jobs)).to eq([])
        end
      end

      describe '#fetch_root_context' do
        it 'loads the active pollable job for this resource and operation into root_job' do
          pollable_job = make_root

          job.send(:fetch_root_context)
          expect(job.send(:root_job)).to eq(pollable_job)
        end

        it 'leaves root_job nil and sub_jobs empty when no active job exists' do
          make_root(state: PollableJobModel::COMPLETE_STATE)

          job.send(:fetch_root_context)
          expect(job.send(:root_job)).to be_nil
          expect(job.send(:sub_jobs)).to eq([])
        end
      end

      describe '#activate_root_job_context' do
        let!(:root_pollable_job) { make_root }

        it 'installs the root_job_guid on the shared enqueuer so sub-jobs are linked' do
          job.send(:activate_root_job_context)
          expect(Jobs::GenericEnqueuer.shared.root_job_guid).to eq(root_pollable_job.guid)
        ensure
          job.send(:deactivate_root_job_context)
        end

        it 'is a no-op when no active pollable job exists yet' do
          root_pollable_job.update(state: PollableJobModel::COMPLETE_STATE)

          job.send(:activate_root_job_context)
          expect(Jobs::GenericEnqueuer.shared.root_job_guid).to be_nil
        ensure
          job.send(:deactivate_root_job_context)
        end
      end

      describe '#deactivate_root_job_context' do
        it 'clears the root_job_guid on the shared enqueuer' do
          make_root
          job.send(:activate_root_job_context)
          job.send(:deactivate_root_job_context)

          expect(Jobs::GenericEnqueuer.shared.root_job_guid).to be_nil
        end
      end

      describe '#sub_jobs_in_flight?' do
        let!(:root_pollable_job) { make_root }

        it 'returns false when there are no sub-jobs' do
          job.send(:fetch_root_context)
          expect(job.send(:sub_jobs_in_flight?)).to be(false)
        end

        it 'returns true when any sub-job is PROCESSING' do
          make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          job.send(:fetch_root_context)
          expect(job.send(:sub_jobs_in_flight?)).to be(true)
        end

        it 'returns true when any sub-job is POLLING' do
          make_sub_job(state: PollableJobModel::POLLING_STATE)
          job.send(:fetch_root_context)
          expect(job.send(:sub_jobs_in_flight?)).to be(true)
        end

        it 'returns false when no root pollable job is registered yet' do
          root_pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
          job.send(:fetch_root_context)
          expect(job.send(:sub_jobs_in_flight?)).to be(false)
        end

        it 'does not raise even when a settled sub-job has failed' do
          make_sub_job(state: PollableJobModel::FAILED_STATE)
          job.send(:fetch_root_context)
          expect(job.send(:sub_jobs_in_flight?)).to be(false)
        end

        it 'persists a user-facing in-progress warning (without the word "async") while deferring' do
          make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          job.send(:fetch_root_context)

          expect(job.send(:sub_jobs_in_flight?)).to be(true)

          warnings = root_pollable_job.reload.warnings
          expect(warnings.map(&:detail)).to contain_exactly(job.send(:in_progress_warning_detail))
          expect(warnings.first.detail).not_to match(/async/i)
        end

        it 'uses the job-provided warning text when the job overrides it' do
          overriding_job = Class.new(test_job_class) do
            def in_progress_warning_detail
              'custom in-progress message for this resource'
            end
          end.new('resource-guid-1')
          make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          overriding_job.send(:fetch_root_context)

          overriding_job.send(:sub_jobs_in_flight?)

          expect(root_pollable_job.reload.warnings.map(&:detail)).to contain_exactly('custom in-progress message for this resource')
        end

        it 'persists the in-progress warning only once across reoccurring runs' do
          make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          job.send(:fetch_root_context)

          job.send(:sub_jobs_in_flight?)
          job.send(:sub_jobs_in_flight?)

          expect(root_pollable_job.reload.warnings.count).to eq(1)
        end

        it 'logs and does not raise when persisting the warning fails' do
          make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          job.send(:fetch_root_context)
          logger = instance_double(Steno::Logger, info: nil, warn: nil, error: nil)
          allow(job).to receive(:logger).and_return(logger)
          allow(JobWarningModel).to receive(:create).and_raise(Sequel::DatabaseError.new('warning insert failed'))

          expect { job.send(:sub_jobs_in_flight?) }.not_to raise_error
          expect(logger).to have_received(:warn).with(/could not add in-progress warning/)
        end

        context 'when some sub-jobs have failed but others are still active' do
          before do
            make_sub_job(state: PollableJobModel::FAILED_STATE)
            make_sub_job(state: PollableJobModel::PROCESSING_STATE)
          end

          it 'returns true (still waiting on the active sub-job)' do
            job.send(:fetch_root_context)
            expect(job.send(:sub_jobs_in_flight?)).to be(true)
          end
        end
      end

      describe '#raise_if_sub_jobs_failed' do
        let!(:root_pollable_job) { make_root }

        it 'does nothing when there are no failed sub-jobs' do
          make_sub_job(state: PollableJobModel::COMPLETE_STATE)
          job.send(:fetch_root_context)
          expect { job.send(:raise_if_sub_jobs_failed) }.not_to raise_error
        end

        it 'does nothing when no active root job exists' do
          root_pollable_job.update(state: PollableJobModel::COMPLETE_STATE)
          job.send(:fetch_root_context)
          expect { job.send(:raise_if_sub_jobs_failed) }.not_to raise_error
        end

        context 'when a settled sub-job has failed' do
          before do
            make_sub_job(state: PollableJobModel::FAILED_STATE,
                         resource_type: 'service_credential_binding', resource_guid: 'binding-1',
                         cf_api_error: YAML.dump({ 'errors' => [{ 'title' => 'CF-UnableToPerform', 'code' => 10_009,
                                                                  'detail' => 'unbind could not be completed: broker exploded' }] }))
            make_sub_job(state: PollableJobModel::COMPLETE_STATE)
          end

          it 'raises a CompoundError of UnprocessableEntity carrying the failed sub-job detail' do
            job.send(:fetch_root_context)
            expect { job.send(:raise_if_sub_jobs_failed) }.to raise_error(CloudController::Errors::CompoundError) do |err|
              expect(err.underlying_errors.map(&:name)).to eq(%w[UnprocessableEntity])
              expect(err.underlying_errors.first.message).to include('unbind could not be completed: broker exploded')
            end
          end

          context 'when the failed sub-job has no stored error detail' do
            before do
              make_sub_job(state: PollableJobModel::FAILED_STATE,
                           resource_type: 'service_credential_binding', resource_guid: 'binding-2')
            end

            it 'falls back to a resource reference for that entry' do
              job.send(:fetch_root_context)
              expect { job.send(:raise_if_sub_jobs_failed) }.to raise_error(CloudController::Errors::CompoundError) do |err|
                expect(err.underlying_errors.map(&:message)).to include(a_string_including('service_credential_binding binding-2'))
              end
            end
          end
        end
      end

      describe 'sub_resource_errors (durable sync-failure hook)' do
        let!(:root_pollable_job) { make_root }

        it 'defaults to none so jobs without sub-resources are unaffected' do
          make_sub_job(state: PollableJobModel::COMPLETE_STATE)
          job.send(:fetch_root_context)
          expect { job.send(:raise_if_sub_jobs_failed) }.not_to raise_error
        end

        context 'when a subclass reports a failed sub-resource with no matching sub-job' do
          let(:job_with_sync_failure) do
            klass = Class.new(test_job_class) do
              def sub_resource_errors
                [['sync-binding', CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'sync unbind failed')]]
              end
            end
            klass.new('resource-guid-1')
          end

          it 'does NOT halt when there is no failed sub-job, so the action can re-run and retry it' do
            job_with_sync_failure.send(:fetch_root_context)
            expect { job_with_sync_failure.send(:raise_if_sub_jobs_failed) }.not_to raise_error
          end

          it 'is reported once a sub-job has terminally failed (action is then skipped), merged with that sub-job' do
            make_sub_job(state: PollableJobModel::FAILED_STATE,
                         resource_type: 'service_credential_binding', resource_guid: 'async-binding',
                         cf_api_error: YAML.dump({ 'errors' => [{ 'detail' => 'async unbind failed' }] }))
            job_with_sync_failure.send(:fetch_root_context)

            expect { job_with_sync_failure.send(:raise_if_sub_jobs_failed) }.to raise_error(CloudController::Errors::CompoundError) do |err|
              expect(err.underlying_errors.map(&:message)).to include(a_string_including('sync unbind failed'), a_string_including('async unbind failed'))
            end
          end
        end

        context 'when a failed sub-resource shares its guid with a failed sub-job' do
          let(:job_with_dup) do
            klass = Class.new(test_job_class) do
              def sub_resource_errors
                [['shared-guid', CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'unbind failed once')]]
              end
            end
            klass.new('resource-guid-1')
          end

          it 'reports the resource only once' do
            make_sub_job(state: PollableJobModel::FAILED_STATE,
                         resource_type: 'service_credential_binding', resource_guid: 'shared-guid',
                         cf_api_error: YAML.dump({ 'errors' => [{ 'detail' => 'unbind failed once' }] }))
            job_with_dup.send(:fetch_root_context)

            expect { job_with_dup.send(:raise_if_sub_jobs_failed) }.to raise_error(CloudController::Errors::CompoundError) do |err|
              expect(err.underlying_errors.size).to eq(1)
            end
          end
        end
      end

      describe '#perform_with_root_job_handling' do
        let!(:root_pollable_job) { make_root }

        it 'activates the root context for the duration of the block' do
          observed = nil
          job.send(:perform_with_root_job_handling) do
            observed = Jobs::GenericEnqueuer.shared.root_job_guid
          end

          expect(observed).to eq(root_pollable_job.guid)
        end

        it 'fetches the root job from the DB only once, even when the block hits several sub-job helpers' do
          allow(PollableJobModel).to receive(:find_active_delete).and_call_original

          job.send(:perform_with_root_job_handling) do
            job.send(:sub_jobs_in_flight?)
            job.send(:raise_if_sub_jobs_failed)
            job.send(:active_sub_jobs)
          end

          expect(PollableJobModel).to have_received(:find_active_delete).once
        end

        it 'always deactivates the root context, even when the block raises' do
          expect do
            job.send(:perform_with_root_job_handling) { raise StandardError.new('boom') }
          end.to raise_error(CloudController::Errors::ApiError)

          expect(Jobs::GenericEnqueuer.shared.root_job_guid).to be_nil
        end

        it 'swallows SubResourceError carrying only in-progress signals' do
          expect do
            job.send(:perform_with_root_job_handling) do
              raise SubResourceError.new([AsyncOperationInProgress.new('async')])
            end
          end.not_to raise_error
        end

        it 'translates SubResourceError with real failures to a CompoundError of UnprocessableEntity' do
          expect do
            job.send(:perform_with_root_job_handling) do
              raise SubResourceError.new([StandardError.new('one broke'), StandardError.new('two broke')])
            end
          end.to raise_error(CloudController::Errors::CompoundError) do |err|
            expect(err.underlying_errors).to all(be_a(CloudController::Errors::ApiError))
            expect(err.underlying_errors.map(&:name)).to eq(%w[UnprocessableEntity UnprocessableEntity])
            expect(err.underlying_errors.map(&:message)).to include(match(/one broke/), match(/two broke/))
          end
        end

        it 'merges current-tick sync failures with settled failed sub-jobs into one CompoundError' do
          make_sub_job(state: PollableJobModel::FAILED_STATE,
                       resource_type: 'service_credential_binding', resource_guid: 'async-binding',
                       cf_api_error: YAML.dump({ 'errors' => [{ 'title' => 'CF-UnableToPerform', 'code' => 10_009,
                                                                'detail' => 'async unbind failed' }] }))

          expect do
            job.send(:perform_with_root_job_handling) do
              raise SubResourceError.new([StandardError.new('sync unbind failed')])
            end
          end.to raise_error(CloudController::Errors::CompoundError) do |err|
            expect(err.underlying_errors.map(&:name)).to all(eq('UnprocessableEntity'))
            expect(err.underlying_errors.map(&:message)).to include(match(/sync unbind failed/), match(/async unbind failed/))
          end
        end

        it 'passes ApiErrors through unchanged' do
          original = CloudController::Errors::ApiError.new_from_details('UnableToPerform', 'delete', 'broker said no')

          expect do
            job.send(:perform_with_root_job_handling) { raise original }
          end.to raise_error(CloudController::Errors::ApiError) do |err|
            expect(err.name).to eq('UnableToPerform')
          end
        end

        it 'surfaces unexpected StandardErrors as UnableToPerform' do
          expect do
            job.send(:perform_with_root_job_handling) { raise StandardError.new('uncategorised') }
          end.to raise_error(CloudController::Errors::ApiError) do |err|
            expect(err.name).to eq('UnableToPerform')
            expect(err.message).to include('uncategorised')
          end
        end
      end

      # Regression: the job YAML-serialises itself on reschedule. A memoized Steno::Logger dragged its
      # file-sink IO into the dump, reviving as an "uninitialized stream" that raised on the next log write.
      describe 'serialisation safety across reschedule' do
        it 'does not carry the logger into its YAML dump' do
          job = VCAP::CloudController::V3::RecursiveDeleteAppJob.new('app-guid', nil)
          job.send(:logger).info('warm up the logger so a memoised one would be cached before dumping')

          expect(YAML.dump(job)).not_to include('Steno::Logger')
        end
      end
    end
  end
end
