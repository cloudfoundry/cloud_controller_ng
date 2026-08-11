require 'spec_helper'
require 'jobs/v3/sub_resource_failures'

module VCAP::CloudController
  module V3
    RSpec.describe SubResourceFailures do
      let(:logger) { instance_double(Steno::Logger, warn: nil) }
      let(:display_name) { 'service_instance.delete' }
      let(:resource_guid) { 'si-guid' }
      let(:root_job_guid) { 'root-guid' }
      let(:label) { "#{display_name} #{resource_guid} (job #{root_job_guid})" }

      def failed_sub_job(resource_guid: 'binding-1', resource_type: 'service_credential_binding', detail: 'broker exploded')
        create(:pollable_job_model, :failed, resource_type: resource_type, resource_guid: resource_guid, detail: detail)
      end

      def settled_sub_job(state:)
        create(:pollable_job_model, state: state, resource_guid: 'other', resource_type: 'service_credential_binding')
      end

      def api_error(message)
        CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', message)
      end

      def build(sub_jobs: [], sub_resource_errors: [])
        described_class.new(sub_jobs: sub_jobs, sub_resource_errors: sub_resource_errors, logger: logger,
                            display_name: display_name, resource_guid: resource_guid, root_job_guid: root_job_guid)
      end

      describe '#compound_error' do
        it 'carries the failed sub-job detail as an UnprocessableEntity' do
          err = build(sub_jobs: [failed_sub_job(detail: 'unbind could not be completed: broker exploded')]).compound_error

          expect(err).to be_a(CloudController::Errors::CompoundError)
          expect(err.underlying_errors.map(&:name)).to eq(%w[UnprocessableEntity])
          expect(err.underlying_errors.first.message).to include('unbind could not be completed: broker exploded')
        end

        it 'falls back to a resource reference when the failed sub-job has no stored detail' do
          err = build(sub_jobs: [failed_sub_job(resource_guid: 'binding-2', detail: nil)]).compound_error

          expect(err.underlying_errors.map(&:message)).to include(a_string_including('service_credential_binding binding-2'))
        end

        it 'ignores non-failed sub-jobs' do
          jobs = [settled_sub_job(state: PollableJobModel::COMPLETE_STATE), settled_sub_job(state: PollableJobModel::POLLING_STATE)]
          expect(build(sub_jobs: jobs).compound_error.underlying_errors).to be_empty
        end

        it 'merges failed sub-jobs with the host sync sub-resource failures' do
          err = build(
            sub_jobs: [failed_sub_job(resource_guid: 'async-binding', detail: 'async unbind failed')],
            sub_resource_errors: [['sync-binding', api_error('sync unbind failed')]]
          ).compound_error

          expect(err.underlying_errors.map(&:message)).to include(a_string_including('sync unbind failed'), a_string_including('async unbind failed'))
        end

        it 'reports a resource only once when it failed both synchronously and as a sub-job (deduped by guid)' do
          err = build(
            sub_jobs: [failed_sub_job(resource_guid: 'shared-guid', detail: 'unbind failed once')],
            sub_resource_errors: [['shared-guid', api_error('unbind failed once')]]
          ).compound_error

          expect(err.underlying_errors.size).to eq(1)
        end

        it 'falls back to the raised failures when nothing durable was recorded' do
          err = build.compound_error([StandardError.new('one broke'), StandardError.new('two broke')])

          expect(err.underlying_errors.map(&:name)).to eq(%w[UnprocessableEntity UnprocessableEntity])
          expect(err.underlying_errors.map(&:message)).to include(match(/one broke/), match(/two broke/))
        end

        it 'prefers durable errors over the raised fallback when both are present' do
          err = build(sub_jobs: [failed_sub_job(detail: 'durable failure')]).compound_error([StandardError.new('transient')])

          expect(err.underlying_errors.map(&:message)).to include(a_string_including('durable failure'))
          expect(err.underlying_errors.map(&:message)).not_to include(a_string_including('transient'))
        end
      end

      describe '#log_immediate' do
        it 'logs one warning per surfaced failure, prefixed with the label' do
          build.log_immediate([StandardError.new('network blip during unbind')])

          expect(logger).to have_received(:warn).with(
            a_string_including(label).and(including('sub-resource deletion failed')).and(including('network blip during unbind'))
          )
        end

        it 'does not log when there are no failures' do
          build.log_immediate([])
          expect(logger).not_to have_received(:warn)
        end
      end

      describe '#log_and_return' do
        it 'logs each underlying error and returns the error unchanged' do
          error = CloudController::Errors::CompoundError.new([api_error('one broke'), api_error('two broke')])

          returned = build.log_and_return(error)

          expect(returned).to be(error)
          expect(logger).to have_received(:warn).with(a_string_including('one broke'))
          expect(logger).to have_received(:warn).with(a_string_including('two broke'))
        end
      end
    end
  end
end
