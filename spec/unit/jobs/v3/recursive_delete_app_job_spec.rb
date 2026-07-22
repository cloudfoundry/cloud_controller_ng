require 'spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'support/shared_examples/jobs/recursive_delete_root_job'
require 'jobs/v3/recursive_delete_app_job'

module VCAP::CloudController
  module V3
    RSpec.describe RecursiveDeleteAppJob do
      let(:user_audit_info) { UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'test@example.com') }
      let(:org) { create(:organization) }
      let(:space) { create(:space, organization: org) }
      let(:app_model) { create(:app_model, space: space, name: 'my-app') }

      subject(:job) { described_class.new(app_model.guid, user_audit_info) }

      before { Jobs::GenericEnqueuer.reset! }
      after { Jobs::GenericEnqueuer.reset! }

      it_behaves_like 'delayed job', described_class

      describe '#perform' do
        def root_pollable(state: PollableJobModel::PROCESSING_STATE)
          create(:pollable_job_model, state: state, resource_guid: app_model.guid, operation: 'app.delete')
        end

        def make_failed_binding(desc:)
          service_instance = create(:managed_service_instance, space:)
          create(:service_binding, app: app_model, service_instance: service_instance).tap do |b|
            b.save_with_attributes_and_new_operation({}, { type: 'delete', state: 'failed', description: desc })
          end
        end

        context 'when the app does not exist' do
          before { app_model.destroy }

          it 'finishes the job' do
            job.perform
            expect(job.finished).to be(true)
          end
        end

        context 'when the app has no service bindings' do
          it 'deletes the app and finishes' do
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
          end
        end

        context 'when the app has synchronous service bindings' do
          let(:service_instance) { create(:managed_service_instance, space:) }
          let!(:binding) { create(:service_binding, app: app_model, service_instance: service_instance) }

          before do
            stub_unbind(binding, accepts_incomplete: true)
          end

          it 'deletes the app and bindings, and finishes' do
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
            expect(ServiceBinding.where(app_guid: app_model.guid).count).to eq(0)
          end
        end

        describe 'stopping the app before deletion' do
          let(:process) { create(:process_model, app: app_model, state: ProcessModel::STARTED) }

          before do
            app_model.update(desired_state: ProcessModel::STARTED)
            process
          end

          it 'stops the app so it is not running during async unbinding' do
            allow_any_instance_of(AppDelete).to receive(:delete).and_raise(
              VCAP::CloudController::SubResourceError.new([VCAP::CloudController::AsyncOperationInProgress.new('async binding')])
            )

            job.perform

            expect(app_model.reload.desired_state).to eq(ProcessModel::STOPPED)
            expect(process.reload.state).to eq(ProcessModel::STOPPED)
          end

          it 'records an audit.app.stop event tagged with delete_triggered so the cascade is transparent' do
            expect { job.perform }.to change { Event.where(type: 'audit.app.stop', actee: app_model.guid).count }.by(1)

            stop_event = Event.where(type: 'audit.app.stop', actee: app_model.guid).last
            expect(stop_event.metadata['delete_triggered']).to be(true)
          end

          context 'when the app is already stopped' do
            before { app_model.update(desired_state: ProcessModel::STOPPED) }

            it 'does not record a redundant audit.app.stop event' do
              expect { job.perform }.not_to(change { Event.where(type: 'audit.app.stop', actee: app_model.guid).count })
            end
          end
        end

        context 'when AppDelete raises SubResourceError carrying only async-in-progress signals' do
          before do
            allow_any_instance_of(AppDelete).to receive(:delete).and_raise(
              VCAP::CloudController::SubResourceError.new([VCAP::CloudController::AsyncOperationInProgress.new('async binding')])
            )
          end

          it 'does not finish or destroy the app' do
            job.perform
            expect(job.finished).to be(false)
            expect(AppModel.find(guid: app_model.guid)).not_to be_nil
          end
        end

        context 'shared root-job behaviour' do
          let(:resource_guid_for_job) { app_model.guid }
          let(:root_operation) { 'app.delete' }

          def expect_no_delete_attempt
            expect_any_instance_of(AppDelete).not_to receive(:delete)
            yield
          end

          def destroy_resource
            app_model.destroy
          end

          it_behaves_like 'a recursive delete root job'

          it 'leaves the app intact on failure so the DELETE can be retried' do
            root = root_pollable
            create(:pollable_job_model, root_job_guid: root.guid, state: PollableJobModel::FAILED_STATE,
                                        resource_type: 'service_credential_binding', resource_guid: 'binding-guid',
                                        cf_api_error: YAML.dump({ 'errors' => [{ 'detail' => 'broker down' }] }))
            expect { job.perform }.to raise_error(CloudController::Errors::CompoundError)
            expect(AppModel.find(guid: app_model.guid)).not_to be_nil
          end
        end

        context 'when a binding is left in delete/failed but no sub-job failed (e.g. a sporadic error)' do
          let!(:sporadically_failed_binding) { make_failed_binding(desc: 'sporadic db error') }
          let!(:root_pollable_job) { root_pollable }

          before { stub_unbind(sporadically_failed_binding, accepts_incomplete: true) }

          it 're-runs the action so the binding is retried and can self-heal' do
            expect_any_instance_of(AppDelete).to receive(:delete).and_call_original
            job.perform
            expect(job.finished).to be(true)
            expect(AppModel.find(guid: app_model.guid)).to be_nil
          end

          it 'logs the failed binding (with detail and job guid) for operator visibility' do
            logger = instance_double(Steno::Logger, info: nil, warn: nil, error: nil)
            allow(job).to receive(:logger).and_return(logger)

            job.perform

            expect(logger).to have_received(:warn).with(
              a_string_including(sporadically_failed_binding.guid).and(including('sporadic db error')).and(including(root_pollable_job.guid))
            )
          end
        end
      end

      describe '#resource_guid' do
        it 'returns the app guid' do
          expect(job.resource_guid).to eq(app_model.guid)
        end
      end

      describe '#resource_type' do
        it 'returns "app"' do
          expect(job.resource_type).to eq('app')
        end
      end

      describe '#display_name' do
        it 'returns "app.delete"' do
          expect(job.display_name).to eq('app.delete')
        end
      end

      describe '#max_attempts' do
        it 'returns 1' do
          expect(job.max_attempts).to eq(1)
        end
      end

      describe '#handle_timeout' do
        it 'is a no-op' do
          expect { job.handle_timeout }.not_to raise_error
        end
      end
    end
  end
end
