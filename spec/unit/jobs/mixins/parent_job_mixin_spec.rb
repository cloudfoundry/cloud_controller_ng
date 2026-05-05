require 'spec_helper'
require 'jobs/mixins/parent_job_mixin'

module VCAP::CloudController
  module Jobs
    RSpec.describe ParentJobMixin do
      let(:test_job_class) do
        Class.new(ReoccurringJob) do
          include ParentJobMixin

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

          expect(job.send(:my_pollable_job)).to eq(pollable_job)
        end

        it 'returns nil when no active job exists' do
          PollableJobModel.make(
            state: PollableJobModel::COMPLETE_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )

          expect(job.send(:my_pollable_job)).to be_nil
        end
      end

      describe '#enqueue_child' do
        let!(:parent_pollable_job) do
          PollableJobModel.make(
            state: PollableJobModel::PROCESSING_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )
        end

        it 'enqueues the job with parent_guid set' do
          child_job = test_job_class.new('child-resource-guid')
          child_pollable_job = job.send(:enqueue_child, child_job)

          expect(child_pollable_job.parent_guid).to eq(parent_pollable_job.guid)
        end
      end

      describe '#children_waiting?' do
        let!(:parent_pollable_job) do
          PollableJobModel.make(
            state: PollableJobModel::PROCESSING_STATE,
            resource_guid: 'resource-guid-1',
            operation: 'test.delete'
          )
        end

        context 'when there are no children' do
          it 'returns false' do
            expect(job.send(:children_waiting?)).to be(false)
          end
        end

        context 'when children are still running' do
          before do
            PollableJobModel.make(state: PollableJobModel::PROCESSING_STATE, parent_guid: parent_pollable_job.guid)
          end

          it 'returns true' do
            expect(job.send(:children_waiting?)).to be(true)
          end
        end

        context 'when all children are complete' do
          before do
            PollableJobModel.make(state: PollableJobModel::COMPLETE_STATE, parent_guid: parent_pollable_job.guid)
          end

          it 'returns false' do
            expect(job.send(:children_waiting?)).to be(false)
          end
        end

        context 'when a child has failed' do
          before do
            PollableJobModel.make(
              state: PollableJobModel::FAILED_STATE,
              parent_guid: parent_pollable_job.guid,
              operation: 'service_instance.delete',
              resource_guid: 'failed-si-guid'
            )
          end

          it 'raises an error with failure details' do
            expect { job.send(:children_waiting?) }.to raise_error(
              CloudController::Errors::ApiError, /Child job\(s\) failed.*service_instance.delete failed-si-guid/
            )
          end
        end

        context 'when there is no parent pollable job' do
          let(:orphan_job) { test_job_class.new('no-such-resource') }

          it 'returns false' do
            expect(orphan_job.send(:children_waiting?)).to be(false)
          end
        end
      end
    end
  end
end
