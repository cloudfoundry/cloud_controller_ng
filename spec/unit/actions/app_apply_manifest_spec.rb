require 'spec_helper'
require 'actions/app_apply_manifest'

module VCAP::CloudController
  RSpec.describe AppApplyManifest do
    subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:process_scale) { instance_double(ProcessScale) }
    let(:app_update) { instance_double(AppUpdate) }
    let(:app_patch_env) { instance_double(AppPatchEnvironmentVariables) }
    let(:process_update) { instance_double(ProcessUpdate) }
    let(:service_binding_create) { instance_double(ServiceBindingCreate) }

    describe '#apply' do
      before do
        allow(ProcessScale).
          to receive(:new).and_return(process_scale)
        allow(process_scale).to receive(:scale)

        allow(AppUpdate).
          to receive(:new).and_return(app_update)
        allow(app_update).to receive(:update)

        allow(ProcessUpdate).
          to receive(:new).and_return(process_update)
        allow(process_update).to receive(:update)

        allow(ServiceBindingCreate).
          to receive(:new).and_return(service_binding_create)
        allow(service_binding_create).to receive(:create)

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
        let(:app_update_environment_variables_message) { message.app_update_environment_variables_message }
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
              with(app, app_update_environment_variables_message)
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

      describe 'updating command' do
        let(:message) { AppManifestMessage.new({ command: 'new-command' }) }
        let(:manifest_process_update_message) { message.manifest_process_update_message }
        let(:app) { AppModel.make }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls ProcessUpdate with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(ProcessUpdate).to have_received(:new).with(user_audit_info)
            expect(process_update).to have_received(:update).
              with(app.web_process, manifest_process_update_message, ManifestStrategy)
          end
        end

        context 'when the request is invalid' do
          let(:message) { AppManifestMessage.new({ command: '' }) }

          before do
            allow(process_update).
              to receive(:update).and_raise(ProcessUpdate::InvalidProcess.new('invalid process'))
          end

          it 'bubbles up the error' do
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(ProcessUpdate::InvalidProcess, 'invalid process')
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

      describe 'updating process' do
        let(:message) { AppManifestMessage.new({ name: 'blah', type: 'process' }) }
        let(:manifest_process_update_message) { message.manifest_process_update_message }
        let(:process) { ProcessModel.make }
        let(:app) { process.app }

        context 'when the request is valid' do
          it 'returns the app' do
            expect(
              app_apply_manifest.apply(app.guid, message)
            ).to eq(app)
          end

          it 'calls ProcessUpdate with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(ProcessUpdate).to have_received(:new).with(user_audit_info)
            expect(process_update).to have_received(:update).with(process, manifest_process_update_message, ManifestStrategy)
          end
        end
      end

      describe 'creating service bindings' do
        let(:message) { AppManifestMessage.new({ services: ['si-name'] }) } # why defined here?
        let(:space) { Space.make }
        let(:app) { AppModel.make(space: space) }

        before do
          TestConfig.override(volume_services_enabled: false)
        end

        context 'valid request' do
          let(:message) { AppManifestMessage.new({ services: ['si-name', 'si2-name'] }) }
          let!(:service_instance) { ManagedServiceInstance.make(name: 'si-name', space: space) }
          let!(:service_instance_2) { ManagedServiceInstance.make(name: 'si2-name', space: space) }

          it 'calls ServiceBindingCreate with the correct arguments' do
            app_apply_manifest.apply(app.guid, message)
            expect(ServiceBindingCreate).to have_received(:new).with(user_audit_info)
            expect(service_binding_create).to have_received(:create).
              with(app, service_instance, instance_of(ServiceBindingCreateMessage), false)
            expect(service_binding_create).to have_received(:create).
              with(app, service_instance_2, instance_of(ServiceBindingCreateMessage), false)
          end

          context 'overriding service_binding_create.create' do
            let(:service_binding_create2) { instance_double(ServiceBindingCreate) }

            before do
              allow(ServiceBindingCreate).to receive(:new).and_return(service_binding_create2)
            end

            it 'calls ServiceBindingCreate.create with the correct type' do
              i = 0
              allow(service_binding_create2).to receive(:create) do |_, _, binding_message, _|
                expect(binding_message.type).to eq('app')
                i += 1
              end
              app_apply_manifest.apply(app.guid, message)
              expect(i).to eq(2)
            end
          end

          context 'service binding already exists' do
            let(:message) { AppManifestMessage.new({ services: ['si-name'] }) }
            let!(:binding) { ServiceBinding.make(service_instance: service_instance, app: app) }

            it 'does not create the binding' do
              app_apply_manifest.apply(app.guid, message)
              expect(service_binding_create).to_not have_received(:create)
            end
          end

          context 'volume_services_enabled' do
            let(:message) { AppManifestMessage.new({ services: ['si-name'] }) }
            before do
              TestConfig.override(volume_services_enabled: true)
            end

            it 'passes the volume_services_enabled_flag to ServiceBindingCreate' do
              app_apply_manifest.apply(app.guid, message)
              expect(service_binding_create).to have_received(:create).
                with(app, service_instance, instance_of(ServiceBindingCreateMessage), true)
            end
          end
        end

        context 'when the service instance does not exist' do
          let(:message) { AppManifestMessage.new({ command: 'new-command', services: ['si-name', 'si-name-2'] }) }
          it 'bubbles up the error' do
            expect {
              app_apply_manifest.apply(app.guid, message)
            }.to raise_error(CloudController::Errors::NotFound, "Service instance 'si-name' not found")
          end
        end
      end
    end
  end
end
