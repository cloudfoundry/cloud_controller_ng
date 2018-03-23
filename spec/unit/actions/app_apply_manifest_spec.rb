require 'spec_helper'
require 'actions/app_apply_manifest'

module VCAP::CloudController
  RSpec.describe AppApplyManifest do
    subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:process_scale) { instance_double(ProcessScale) }
    let(:app_update) { instance_double(AppUpdate) }
    let(:app_patch_env) { instance_double(AppPatchEnvironmentVariables) }

    describe '#apply' do
      before do
        allow(ProcessScale).
          to receive(:new).and_return(process_scale)
        allow(process_scale).to receive(:scale)

        allow(AppUpdate).
          to receive(:new).and_return(app_update)
        allow(app_update).to receive(:update)

        allow(AppPatchEnvironmentVariables).
          to receive(:new).and_return(app_patch_env)
        allow(app_patch_env).to receive(:patch)
      end

      describe 'scaling instances' do
        let(:message) { AppManifestMessage.new({ name: 'blah', instances: 4 }) }
        let(:process_scale_message) { message.process_scale_message }
        let(:process) { ProcessModel.make(instances: 1) }
        let(:app) { process.app }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls ProcessScale with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(ProcessScale).to have_received(:new).with(user_audit_info, process, process_scale_message)
            expect(process_scale).to have_received(:scale)
          end
        end

        context 'when process scale raises an exception' do
          let(:process_scale_message) { instance_double(ProcessScaleMessage) }
          let(:message) { instance_double(AppManifestMessage, process_scale_message: process_scale_message) }

          before do
            allow(process_scale).
              to receive(:scale).and_raise(ProcessScale::InvalidProcess.new('instances less_than_zero'))
          end

          it 'bubbles up the error' do
            expect(process.instances).to eq(1)
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(ProcessScale::InvalidProcess, 'instances less_than_zero')
          end
        end
      end

      describe 'scaling memory' do
        let(:message) { AppManifestMessage.new({ name: 'blah', memory: '256MB' }) }
        let(:process_scale_message) { message.process_scale_message }
        let(:process) { ProcessModel.make(memory: 512) }
        let(:app) { process.app }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls ProcessScale with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(ProcessScale).to have_received(:new).with(user_audit_info, process, process_scale_message)
            expect(process_scale).to have_received(:scale)
          end
        end

        context 'when the request is invalid due to an invalid unit suffix' do
          let(:message) { AppManifestMessage.new({ name: 'blah', memory: '256BIG' }) }

          before do
            allow(process_scale).
              to receive(:scale).and_raise(ProcessScale::InvalidProcess.new('memory must use a supported unit'))
          end

          it 'bubbles up the error' do
            expect(process.memory).to eq(512)
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(ProcessScale::InvalidProcess, 'memory must use a supported unit')
          end
        end
      end

      describe 'updating buildpack' do
        let(:buildpack) { VCAP::CloudController::Buildpack.make }
        let(:message) { AppManifestMessage.new({ name: 'blah', buildpack: buildpack.name }) }
        let(:app_update_message) { message.app_update_message }
        let(:app) { AppModel.make }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls AppUpdate with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(AppUpdate).to have_received(:new).with(user_audit_info)
            expect(app_update).to have_received(:update).
              with(app, app_update_message, instance_of(AppBuildpackLifecycle))
          end
        end

        context 'when the request is invalid due to failure to update the app' do
          let(:message) { AppManifestMessage.new({ name: 'blah', buildpack: buildpack.name }) }

          before do
            allow(app_update).
              to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
          end

          it 'bubbles up the error' do
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(AppUpdate::InvalidApp, 'invalid app')
          end
        end
      end

      describe 'updating stack' do
        let(:message) { AppManifestMessage.new({ name: 'stack-test', stack: 'cflinuxfs2' }) }
        let(:app_update_message) { message.app_update_message }
        let(:app) { AppModel.make }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls AppUpdate with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(AppUpdate).to have_received(:new).with(user_audit_info)
            expect(app_update).to have_received(:update).
              with(app, app_update_message, instance_of(AppBuildpackLifecycle))
          end
        end

        context 'when the request is invalid' do
          let(:message) { AppManifestMessage.new({ name: 'stack-test', stack: 'no-such-stack' }) }

          before do
            allow(app_update).
              to receive(:update).and_raise(AppUpdate::InvalidApp.new('invalid app'))
          end

          it 'bubbles up the error' do
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(AppUpdate::InvalidApp, 'invalid app')
          end
        end
      end

      describe 'updating environment variables' do
        let(:message) { AppManifestMessage.new({ env: { 'foo': 'bar' } }) }
        let(:manifest_env_update_message) { message.manifest_env_update_message }
        let(:app) { AppModel.make }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls AppPatchEnvironmentVariables with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(AppPatchEnvironmentVariables).to have_received(:new).with(user_audit_info)
            expect(app_patch_env).to have_received(:patch).
              with(app, manifest_env_update_message)
          end
        end

        context 'when the request is invalid' do
          let(:message) { AppManifestMessage.new({ env: 'not-a-hash' }) }

          before do
            allow(app_patch_env).
              to receive(:patch).and_raise(AppPatchEnvironmentVariables::InvalidApp.new('invalid app'))
          end

          it 'bubbles up the error' do
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(AppPatchEnvironmentVariables::InvalidApp, 'invalid app')
          end
        end
      end

      describe 'converting ManifestProcessScaleMessages to ProcessScaleMessages' do
        let(:message) { AppManifestMessage.new(params) }
        let(:process_scale_message) { message.process_scale_message }

        context 'when all params are given' do
          let(:params) do { name: 'blah1', instances: 4, disk_quota: '3500MB', memory: '120MB' } end
          it 'converts them all' do
            expect(process_scale_message.instances).to eq(4)
            expect(process_scale_message.requested?(:disk_quota)).to be_falsey
            expect(process_scale_message.disk_in_mb).to eq(3500)
            expect(process_scale_message.requested?(:memory)).to be_falsey
            expect(process_scale_message.memory_in_mb).to eq(120)
          end
        end

        context 'when no disk_quota is given' do
          let(:params) do { name: 'blah2', instances: 4, memory: '120MB' } end
          it "doesn't set anything for disk_in_mb" do
            expect(process_scale_message.instances).to eq(4)
            expect(process_scale_message.requested?(:disk_quota)).to be_falsey
            expect(process_scale_message.requested?(:disk_in_mb)).to be_falsey
            expect(process_scale_message.requested?(:memory)).to be_falsey
            expect(process_scale_message.memory_in_mb).to eq(120)
          end
        end

        context 'when no memory is given' do
          let(:params) do { name: 'blah3', instances: 4, disk_quota: '3500MB' } end
          it "doesn't set anything for memory_in_mb" do
            expect(process_scale_message.instances).to eq(4)
            expect(process_scale_message.requested?(:disk_quota)).to be_falsey
            expect(process_scale_message.disk_in_mb).to eq(3500)
            expect(process_scale_message.requested?(:memory)).to be_falsey
            expect(process_scale_message.requested?(:memory_in_mb)).to be_falsey
          end
        end

        context 'when no scaling fields are given' do
          let(:params) do { name: 'blah4' } end
          it "doesn't set any scaling fields" do
            expect(process_scale_message.requested?(:instances)).to be_falsey
            expect(process_scale_message.requested?(:disk_quota)).to be_falsey
            expect(process_scale_message.requested?(:disk_in_mb)).to be_falsey
            expect(process_scale_message.requested?(:memory)).to be_falsey
            expect(process_scale_message.requested?(:memory_in_mb)).to be_falsey
          end
        end
      end
    end
  end
end
