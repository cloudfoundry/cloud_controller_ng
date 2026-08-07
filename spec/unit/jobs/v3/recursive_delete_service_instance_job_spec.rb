require 'spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'support/shared_examples/jobs/recursive_delete_root_job'
require 'jobs/v3/recursive_delete_service_instance_job'
require 'cloud_controller/errors/api_error'
require 'cloud_controller/user_audit_info'
require 'actions/v3/service_instance_delete'

module VCAP::CloudController
  module V3
    RSpec.describe RecursiveDeleteServiceInstanceJob do
      let(:user_audit_info) { UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'foo@example.com') }
      let(:service_instance) { create(:managed_service_instance, service_plan:) }
      let(:service_plan) { create(:service_plan, service: service_offering) }
      let(:service_offering) { create(:service) }

      subject(:job) { described_class.new(service_instance.guid, user_audit_info) }

      before { Jobs::GenericEnqueuer.reset! }

      it_behaves_like 'delayed job', described_class

      describe '#perform' do
        let(:delete_response) { { finished: false, operation: 'test-operation' } }
        let(:poll_response) { { finished: false } }
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceDelete,
                 { delete: delete_response, poll: poll_response, update_last_operation_with_failure: nil })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceDelete).to receive(:new).and_return(action)
        end

        def root_pollable(state: PollableJobModel::PROCESSING_STATE)
          create(:pollable_job_model, state: state, resource_guid: service_instance.guid, operation: 'service_instance.delete')
        end

        def make_failed_binding(desc:)
          create(:service_binding, service_instance: service_instance).tap do |b|
            b.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed', description: desc })
          end
        end

        def make_failed_key(desc:)
          create(:service_key, service_instance: service_instance).tap do |k|
            k.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed', description: desc })
          end
        end

        def make_failed_route_binding(desc:)
          create(:route_binding, service_instance: service_instance).tap do |rb|
            rb.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed', description: desc })
          end
        end

        it 'passes fail_if_in_progress: false to the action' do
          job.perform

          expect(VCAP::CloudController::V3::ServiceInstanceDelete).to have_received(:new).with(
            service_instance,
            an_instance_of(VCAP::CloudController::Repositories::ServiceEventRepository),
            fail_if_in_progress: false
          ).at_least(:once)
        end

        context 'when a binding-delete sub-job has been enqueued (async)' do
          before do
            allow(action).to receive(:delete).and_raise(VCAP::CloudController::SubResourceError.new([VCAP::CloudController::AsyncOperationInProgress.new('async')]))
          end

          it 'swallows the error, does not finish, and does not poll the broker this cycle' do
            expect { job.perform }.not_to raise_error
            expect(job.finished).to be_falsey
            expect(action).not_to have_received(:poll)
          end
        end

        context 'shared root-job behaviour' do
          let(:resource_guid_for_job) { service_instance.guid }
          let(:root_operation) { 'service_instance.delete' }

          def expect_no_delete_attempt
            expect(action).not_to receive(:delete)
            yield
          end

          def destroy_resource
            service_instance.destroy
          end

          it_behaves_like 'a recursive delete root job'
        end

        context 'while binding deletions are still in flight' do
          let!(:root_pollable_job) { root_pollable }
          let!(:in_flight_sub) do
            create(:pollable_job_model, root_job_guid: root_pollable_job.guid, state: PollableJobModel::PROCESSING_STATE,
                                        resource_type: 'service_credential_binding', resource_guid: 'in-flight-binding')
          end

          it 'defers without attempting the delete or poll this cycle' do
            expect(action).not_to receive(:delete)
            expect(action).not_to receive(:poll)

            job.perform

            expect(job.finished).to be_falsey
          end

          it 'adds an in-progress warning to the root job so `cf ... -w` and the job resource surface it' do
            job.perform

            expect(root_pollable_job.reload.warnings_dataset.map(:detail)).to include(a_string_including('dependent resources'))
          end
        end

        context 'when a binding is left in delete/failed but no sub-job failed (e.g. a sporadic error)' do
          let!(:sporadically_failed_binding) { make_failed_binding(desc: 'sporadic db error') }
          let!(:root_pollable_job) { root_pollable }

          it 're-runs the action so the binding is retried and can self-heal' do
            expect(action).to receive(:delete).and_return({ finished: true })
            job.perform
            expect(job.finished).to be(true)
          end
        end

        context 'when different child types (key, route binding, service binding) fail or succeed independently' do
          let(:service_offering) { create(:service, requires: %w[route_forwarding]) }
          let!(:root_pollable_job) { root_pollable }

          it 'collects delete/failed children across all three types, ignoring the ones still succeeding' do
            failed_key = make_failed_key(desc: 'key unbind failed')
            failed_route = make_failed_route_binding(desc: 'route unbind failed')
            failed_binding = make_failed_binding(desc: 'binding unbind failed')
            # A second binding still succeeding/settling must be ignored by the collector.
            create(:service_binding, service_instance: service_instance)

            collected = job.send(:sub_resource_errors)

            expect(collected.map(&:first)).to contain_exactly(failed_key.guid, failed_route.guid, failed_binding.guid)
            expect(collected.map { |_guid, err| err.message }).to include(
              a_string_including('key unbind failed'),
              a_string_including('route unbind failed'),
              a_string_including('binding unbind failed')
            )
          end

          it 'raises the failure (surfaced on the job resource) without stamping the instance last_operation' do
            failed_route = make_failed_route_binding(desc: 'route unbind failed')
            create(:pollable_job_model, :failed, root_job_guid: root_pollable_job.guid,
                                                 resource_type: 'route_binding', resource_guid: failed_route.guid, detail: 'route unbind failed')

            expect { job.perform }.to raise_error(CloudController::Errors::CompoundError) do |err|
              expect(err.underlying_errors.map(&:message)).to include(a_string_including('route unbind failed'))
            end

            # The binding-phase failure belongs to the binding's own last_operation, not the instance's.
            expect(action).not_to have_received(:update_last_operation_with_failure)
          end

          it 'defers (does not raise or finish) when one child already failed but another is still in flight' do
            make_failed_key(desc: 'key unbind failed')
            # Another child's sub-job is still processing — the root must wait for it before surfacing the failure.
            create(:pollable_job_model, root_job_guid: root_pollable_job.guid, state: PollableJobModel::PROCESSING_STATE,
                                        resource_type: 'route_binding', resource_guid: 'in-flight-route')

            expect(action).not_to receive(:delete)
            expect { job.perform }.not_to raise_error
            expect(job.finished).to be_falsey
          end
        end

        context 'when a previous delete attempt for this instance failed and left stale pollable rows' do
          let!(:previous_failed_root) { root_pollable(state: PollableJobModel::FAILED_STATE) }

          let!(:previous_failed_sub) do
            create(:pollable_job_model,
                   root_job_guid: previous_failed_root.guid,
                   state: PollableJobModel::FAILED_STATE,
                   resource_type: 'service_credential_binding',
                   resource_guid: 'binding-guid')
          end

          it 'ignores the stale rows and runs the delete this cycle' do
            expect(action).to receive(:delete).and_return({ finished: true })
            job.perform
            expect(job.finished).to be(true)
          end
        end
      end

      describe 'handle timeout' do
        let(:action) do
          double(VCAP::CloudController::V3::ServiceInstanceDelete, { update_last_operation_with_failure: nil })
        end

        before do
          allow(VCAP::CloudController::V3::ServiceInstanceDelete).to receive(:new).and_return(action)
        end

        it 'asks the action to update the last operation' do
          job.handle_timeout

          expect(action).to have_received(:update_last_operation_with_failure).with('Service Broker failed to deprovision within the required time.')
        end
      end

      describe '#operation' do
        it 'returns "deprovision"' do
          expect(job.operation).to eq(:deprovision)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(job.operation_type).to eq('delete')
        end
      end

      describe '#resource_type' do
        it 'returns "service_instance"' do
          expect(job.resource_type).to eq('service_instance')
        end
      end

      describe '#resource_guid' do
        it 'returns the service instance guid' do
          expect(job.resource_guid).to eq(service_instance.guid)
        end
      end

      describe '#display_name' do
        it 'returns the display name' do
          expect(job.display_name).to eq('service_instance.delete')
        end
      end
    end
  end
end
