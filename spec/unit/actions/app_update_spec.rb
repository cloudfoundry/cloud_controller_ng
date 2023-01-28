require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  RSpec.describe AppUpdate do
    subject(:app_update) { AppUpdate.new(user_audit_info, runners: runners) }

    let(:app_model) { AppModel.make(name: app_name) }
    let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app_model) }
    let!(:worker_process) { VCAP::CloudController::ProcessModel.make(app: app_model) }
    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:buildpack) { 'http://original.com' }
    let(:app_name) { 'original name' }
    let!(:ruby_buildpack) { Buildpack.make(name: 'ruby', stack: stack.name) }
    let(:stack) { Stack.make(name: 'SUSE') }
    let(:runners) { instance_double(Runners, runner_for_process: runner) }
    let(:runner) { instance_double(Diego::Runner, update_metric_tags: nil) }

    before do
      app_model.lifecycle_data.update(buildpacks: Array(buildpack), stack: Stack.default.name)
    end

    describe '#update' do
      let(:lifecycle) { AppLifecycleProvider.provide_for_update(message, app_model) }
      let(:message) do
        AppUpdateMessage.new({
          name: 'new name',
        })
      end

      describe 'audit events' do
        it 'creates an audit event' do
          expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_update).with(
            app_model,
            app_model.space,
            user_audit_info,
            {
              'name' => 'new name',
            },
            manifest_triggered: false
          )

          app_update.update(app_model, message, lifecycle)
        end

        context 'when the app_update is triggered by applying a manifest' do
          subject(:app_update) { AppUpdate.new(user_audit_info, manifest_triggered: true, runners: runners) }

          it 'sends manifest_triggered: true to the event repository' do
            expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_update).with(
              app_model,
              app_model.space,
              user_audit_info,
              {
                'name' => 'new name',
              },
              manifest_triggered: true
            )

            app_update.update(app_model, message, lifecycle)
          end
        end
      end

      describe 'updating the name' do
        let(:message) { AppUpdateMessage.new({ name: 'new name' }) }

        it 'updates the apps name' do
          expect(app_model.name).to eq('original name')
          expect(app_model.lifecycle_data.buildpacks).to eq(['http://original.com'])

          app_update.update(app_model, message, lifecycle)
          app_model.reload

          expect(app_model.name).to eq('new name')
          expect(app_model.lifecycle_data.buildpacks).to eq(['http://original.com'])
        end

        context 'when app processes are started' do
          let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STARTED) }
          let!(:worker_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STARTED) }

          it 'updates the metric tags for each process on the backend' do
            app_update.update(app_model, message, lifecycle)

            expect(runners).to have_received(:runner_for_process).with(web_process)
            expect(runners).to have_received(:runner_for_process).with(worker_process)
            expect(runner).to have_received(:update_metric_tags).twice
          end

          context 'when there is a CannotCommunicateWithDiegoError' do
            before do
              allow(runner).to receive(:update_metric_tags).and_invoke(
                lambda { raise(Diego::Runner::CannotCommunicateWithDiegoError.new) },
                lambda {}
              )
            end

            it 'logs the error for each process and continues' do
              expect_any_instance_of(Steno::Logger).to receive(:error)
              expect { app_update.update(app_model, message, lifecycle) }.not_to raise_error

              expect(runners).to have_received(:runner_for_process).with(web_process)
              expect(runners).to have_received(:runner_for_process).with(worker_process)
            end

            it 'still modifies the app' do
              expect { app_update.update(app_model, message, lifecycle) }.not_to raise_error
              app_model.reload
              expect(app_model.name).to eq('new name')
            end

            it 'updates the process updated_at timestamps so that it still converges' do
              old_web_process_updated_at = web_process.updated_at
              old_worker_process_updated_at = worker_process.updated_at
              sleep 1
              expect { app_update.update(app_model, message, lifecycle) }.not_to raise_error
              web_process.reload
              worker_process.reload
              expect(web_process.updated_at).to be > old_web_process_updated_at
              expect(worker_process.updated_at).to be > old_worker_process_updated_at
            end
          end

          context 'when there is a different error' do
            before do
              allow(runner).to receive(:update_metric_tags).and_raise(RuntimeError, 'some-other-error')
            end

            it 'does not rescue the error' do
              expect { app_update.update(app_model, message, lifecycle) }.to raise_error(RuntimeError, 'some-other-error')

              expect(runners).to have_received(:runner_for_process).with(web_process)
              expect(runners).to_not have_received(:runner_for_process).with(worker_process)
            end

            it 'still modifies the app' do
              expect { app_update.update(app_model, message, lifecycle) }.to raise_error(RuntimeError, 'some-other-error')
              app_model.reload
              expect(app_model.name).to eq('new name')
            end

            it 'updates the process updated_at timestamps so that it still converges' do
              old_web_process_updated_at = web_process.updated_at
              old_worker_process_updated_at = worker_process.updated_at
              sleep 1
              expect { app_update.update(app_model, message, lifecycle) }.to raise_error(RuntimeError, 'some-other-error')
              web_process.reload
              worker_process.reload
              expect(web_process.updated_at).to be > old_web_process_updated_at
              expect(worker_process.updated_at).to be > old_worker_process_updated_at
            end
          end
        end

        context 'when app processes are stopped' do
          let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STOPPED) }
          let!(:worker_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STOPPED) }

          it 'updates the apps name' do
            expect(app_model.name).to eq('original name')

            app_update.update(app_model, message, lifecycle)
            app_model.reload

            expect(app_model.name).to eq('new name')
          end

          it 'does not update the metric tags' do
            app_update.update(app_model, message, lifecycle)

            expect(runners).to_not have_received(:runner_for_process)
            expect(runner).to_not have_received(:update_metric_tags)
          end
        end
      end

      describe 'updating lifecycle' do
        let(:message) do
          AppUpdateMessage.new({
              lifecycle: {
                type: 'buildpack',
                data: { buildpacks: ['http://new-buildpack.url', 'ruby'], stack: stack.name }
              }
            })
        end

        it 'updates the apps lifecycle' do
          expect(app_model.name).to eq('original name')
          expect(app_model.lifecycle_data.buildpacks).to eq(['http://original.com'])
          expect(app_model.lifecycle_data.stack).to eq(Stack.default.name)

          app_update.update(app_model, message, lifecycle)
          app_model.reload

          expect(app_model.name).to eq('original name')
          expect(app_model.lifecycle_data.buildpacks).to eq(['http://new-buildpack.url', 'ruby'])
          expect(app_model.lifecycle_data.stack).to eq(stack.name)
          expect(runner).to_not have_received(:update_metric_tags)
        end

        context 'when the lifecycle is invalid' do
          let(:message) do
            AppUpdateMessage.new({
              lifecycle: {
                type: 'buildpack',
                data: { buildpacks: ['http://new-buildpack.url', 'ruby'], stack: 'non-existent-stack' }
              }
            })
          end

          it 'raises an AppUpdate::InvalidApp error' do
            expect { app_update.update(app_model, message, lifecycle)
            }.to raise_error(AppUpdate::InvalidApp, 'Buildpack "ruby" must be an existing admin buildpack or a valid git URI, Stack must be an existing stack')
          end
        end

        context 'when changing the lifecycle type' do
          let(:message) do
            AppUpdateMessage.new({
              lifecycle: {
                type: 'docker',
                data: {}
              }
            })
          end

          it 'raises an InvalidApp error' do
            expect(app_model.lifecycle_type).to eq('buildpack')

            expect {
              app_update.update(app_model, message, lifecycle)
            }.to raise_error(AppUpdate::InvalidApp, /Lifecycle type cannot be changed/)
          end
        end

        context 'when custom buildpacks are disabled and user provides a custom buildpack' do
          let(:message) do
            AppUpdateMessage.new({
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: ['https://github.com/buildpacks/my-special-buildpack'],
                  stack:      'cflinuxfs3'
                }
              }
            })
          end

          before do
            TestConfig.override(disable_custom_buildpacks: true)
          end

          it 'raises an InvalidApp error' do
            expect {
              app_update.update(app_model, message, lifecycle)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end

          it 'does not modify the app' do
            lifecycle_data = app_model.lifecycle_data
            expect {
              app_update.update(app_model, message, lifecycle) rescue nil
            }.not_to change { [app_model, lifecycle_data, Event.count] }
          end
        end
      end

      describe 'updating metadata' do
        let!(:app_annotation) { AppAnnotationModel.make(app: app_model, key: 'existing_anno', value: 'original-value') }
        let!(:delete_annotation) { AppAnnotationModel.make(app: app_model, key: 'please', value: 'delete this') }

        let(:message) do
          AppUpdateMessage.new({
            metadata: {
              labels: {
                release: 'stable',
                'joyofcooking.com/potato': 'mashed'
              },
              annotations: {
                contacts: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
                existing_anno: 'new-value',
                please: nil,
              }
            }
          })
        end

        it 'updates the labels' do
          app_update.update(app_model, message, lifecycle)
          expect(AppLabelModel.find(resource_guid: app_model.guid, key_name: 'release').value).to eq 'stable'
          expect(AppLabelModel.find(resource_guid: app_model.guid, key_prefix: 'joyofcooking.com', key_name: 'potato').value).to eq 'mashed'
        end

        it 'updates the annotations' do
          app_update.update(app_model, message, lifecycle)
          expect(app_model).to have_annotations(
            { key: 'contacts', value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' },
            { key: 'existing_anno', value: 'new-value' },
          )
          expect(AppAnnotationModel.find(resource_guid: app_model.guid, key: 'please')).to be_nil
        end
      end

      context 'when the app is invalid' do
        before do
          allow(app_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('something'))
        end

        it 'raises an invalid app error' do
          expect { app_update.update(app_model, message, lifecycle) }.to raise_error(AppUpdate::InvalidApp)
        end
      end
    end
  end
end
