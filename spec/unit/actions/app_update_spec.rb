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
    let!(:ruby_buildpack) { Buildpack.make(name: 'ruby', stack: stack.name) }
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
          subject(:app_update) { AppUpdate.new(user_audit_info, manifest_triggered: true) }

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
