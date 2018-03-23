require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  RSpec.describe AppUpdate do
    subject(:app_update) { AppUpdate.new(user_audit_info) }

    let(:app_model) { AppModel.make(name: app_name) }
    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:buildpack) { 'http://original.com' }
    let(:app_name) { 'original name' }
    let!(:ruby_buildpack) { Buildpack.make(name: 'ruby') }
    let(:stack) { Stack.make(name: 'SUSE') }

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

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_update).with(
          app_model,
          app_model.space,
          user_audit_info,
          {
            'name' => 'new name',
          }
        )

        app_update.update(app_model, message, lifecycle)
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
            }.to raise_error(AppUpdate::InvalidApp, 'Stack must be an existing stack')
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
            }.to raise_error(AppUpdate::InvalidApp, 'Lifecycle type cannot be changed')
          end
        end

        context 'when custom buildpacks are disabled and user provides a custom buildpack' do
          let(:message) do
            AppUpdateMessage.new({
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpacks: ['https://github.com/buildpacks/my-special-buildpack'],
                  stack:      'cflinuxfs2'
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

      describe 'updating command' do
        let!(:process_model) { ProcessModel.make(app: app_model) }
        let(:app_model) { AppModel.make(name: app_name) }
        let(:message) do
          AppUpdateMessage.new({
            command: 'my new command'
          })
        end

        it 'updates the apps command' do
          expect(app_model.name).to eq('original name')
          expect(app_model.web_process.command).to eq(nil)

          app_update.update(app_model, message, lifecycle)
          app_model.reload

          expect(app_model.name).to eq('original name')
          expect(app_model.web_process.command).to eq('my new command')
        end
      end

      describe 'resetting command' do
        let!(:process_model) { ProcessModel.make(app: app_model) }
        let(:app_model) { AppModel.make(name: app_name) }
        let(:message) do
          AppUpdateMessage.new({
            command: nil
          })
        end

        it 'resets the apps command' do
          app_model.web_process.command = 'old-command'
          app_model.web_process.save

          expect(app_model.name).to eq('original name')
          expect(app_model.web_process.command).to eq('old-command')

          app_update.update(app_model, message, lifecycle)
          app_model.reload

          expect(app_model.name).to eq('original name')
          expect(app_model.web_process.command).to be_nil
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
