require 'spec_helper'
require 'jobs/mixins/root_job_mixin'

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
        end
      end

      let(:job) { test_job_class.new('resource-guid-1') }

      describe '#my_pollable_job' do
        it 'finds the active pollable job for this resource and operation' do
          pollable_job = PollableJobModel.make(
            state: PollableJobModel::PROCESSING_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )

          expect(job.send(:root_job)).to eq(pollable_job)
        end

        it 'returns nil when no active job exists' do
          PollableJobModel.make(
            state: PollableJobModel::COMPLETE_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )

          expect(job.send(:root_job)).to be_nil
        end
      end

      describe '#activate_root_job_context' do
        let!(:root_pollable_job) do
          PollableJobModel.make(
            state: PollableJobModel::PROCESSING_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )
        end

        it 'sets root_job_guid on the shared enqueuer so sub-jobs are linked' do
          job.send(:activate_root_job_context)
          sub_job = test_job_class.new('sub-resource-guid')
          sub_pollable_job = Jobs::GenericEnqueuer.shared.enqueue_pollable(sub_job)

          expect(sub_pollable_job.root_job_guid).to eq(root_pollable_job.guid)
        ensure
          job.send(:deactivate_root_job_context)
        end
      end

      describe '#sub_jobs_pending?' do
        let!(:root_pollable_job) do
          PollableJobModel.make(
            state: PollableJobModel::PROCESSING_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )
        end

        before do
          job.send(:activate_root_job_context)
        end

        after do
          job.send(:deactivate_root_job_context)
        end

        context 'when there are no sub-jobs' do
          it 'returns false' do
            expect(job.send(:sub_jobs_pending?)).to be(false)
          end
        end

        context 'when sub-jobs are still running' do
          before do
            PollableJobModel.make(state: PollableJobModel::PROCESSING_STATE, root_job_guid: root_pollable_job.guid)
            job.send(:activate_root_job_context)
          end

          it 'returns true' do
            expect(job.send(:sub_jobs_pending?)).to be(true)
          end
        end

        context 'when all sub-jobs are complete' do
          before do
            PollableJobModel.make(state: PollableJobModel::COMPLETE_STATE, root_job_guid: root_pollable_job.guid)
            job.send(:activate_root_job_context)
          end

          it 'returns false' do
            expect(job.send(:sub_jobs_pending?)).to be(false)
          end
        end

        context 'when a sub-job has failed and none are active' do
          before do
            PollableJobModel.make(
              state: PollableJobModel::FAILED_STATE,
              root_job_guid: root_pollable_job.guid,
              operation: 'service_instance.delete',
              resource_guid: 'failed-si-guid'
            )
            job.send(:activate_root_job_context)
          end

          it 'raises an error with failure details' do
            expect { job.send(:sub_jobs_pending?) }.to raise_error(
              CloudController::Errors::ApiError, /Sub-job\(s\) failed.*service_instance.delete failed-si-guid/
            )
          end
        end

        context 'when a sub-job has failed but others are still active' do
          before do
            PollableJobModel.make(state: PollableJobModel::PROCESSING_STATE, root_job_guid: root_pollable_job.guid)
            PollableJobModel.make(
              state: PollableJobModel::FAILED_STATE,
              root_job_guid: root_pollable_job.guid,
              operation: 'service_instance.delete',
              resource_guid: 'failed-si-guid'
            )
            job.send(:activate_root_job_context)
          end

          it 'returns true and adds a warning' do
            job.instance_variable_set(:@warnings, [])
            expect(job.send(:sub_jobs_pending?)).to be(true)
            expect(job.instance_variable_get(:@warnings)).to include(
              hash_including(detail: /sub-jobs have failed/)
            )
          end
        end

        context 'when there is no root pollable job' do
          let(:orphan_job) { test_job_class.new('no-such-resource') }

          it 'returns false' do
            expect(orphan_job.send(:sub_jobs_pending?)).to be(false)
          end
        end
      end
    end
  end
end
