require 'spec_helper'
require 'actions/process_scale'

module VCAP::CloudController
  RSpec.describe ProcessScale do
    subject(:process_scale) { ProcessScale.new(user_audit_info, process, message) }
    let(:valid_message_params) do
      {
        instances: 2,
        memory_in_mb: 100,
        disk_in_mb: 200,
        log_quota_in_bps: 409_600
      }
    end
    let(:message) { ProcessScaleMessage.new(valid_message_params) }
    let(:app) { AppModel.make }
    let!(:process) { ProcessModelFactory.make(disk_quota: 50, app: app) }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

    describe '#scale' do
      it 'scales the process record' do
        expect(process.instances).not_to eq(2)
        expect(process.memory).not_to eq(100)
        expect(process.disk_quota).not_to eq(200)
        expect(process.log_quota).not_to eq(409_600)

        process_scale.scale

        expect(process.reload.instances).to eq(2)
        expect(process.reload.memory).to eq(100)
        expect(process.reload.disk_quota).to eq(200)
        expect(process.log_quota).to eq(409_600)
      end

      it 'does not set instances if the user did not request it' do
        valid_message_params.delete(:instances)
        original_value = process.instances

        process_scale.scale

        expect(process.instances).to eq(original_value)
      end

      it 'does not set memory if the user did not request it' do
        valid_message_params.delete(:memory_in_mb)
        original_value = process.memory

        process_scale.scale

        expect(process.memory).to eq(original_value)
      end

      it 'does not set disk if the user did not request it' do
        valid_message_params.delete(:disk_in_mb)
        original_value = process.disk_quota

        process_scale.scale

        expect(process.disk_quota).to eq(original_value)
      end

      it 'does not set log quota if the user did not request it' do
        valid_message_params.delete(:log_quota_in_bps)
        original_value = process.log_quota

        process_scale.scale

        expect(process.log_quota).to eq(original_value)
      end

      describe 'audit events' do
        it 'creates a process audit event' do
          expect(Repositories::ProcessEventRepository).to receive(:record_scale).with(
            process,
            user_audit_info,
            {
              'instances'    => 2,
              'memory_in_mb' => 100,
              'disk_in_mb'   => 200,
              'log_quota_in_bps' => 409_600,
            },
            manifest_triggered: false
          )

          process_scale.scale
        end

        context 'when the scale is triggered by applying a manifest' do
          subject(:process_scale) { ProcessScale.new(user_audit_info, process, message, manifest_triggered: true) }

          it 'sends manifest_triggered: true to the event repository' do
            expect(Repositories::ProcessEventRepository).to receive(:record_scale).with(
              process,
              user_audit_info,
              {
                'instances'    => 2,
                'memory_in_mb' => 100,
                'disk_in_mb'   => 200,
                'log_quota_in_bps' => 409_600,
              },
              manifest_triggered: true
            )

            process_scale.scale
          end
        end
      end

      context 'when the process is invalid' do
        before do
          allow(process).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an invalid error' do
          expect {
            process_scale.scale
          }.to raise_error(ProcessScale::InvalidProcess, 'the message')
        end
      end

      context 'when the parent app is being deployed' do
        before do
          VCAP::CloudController::DeploymentModel.make(app: app, state: 'DEPLOYING')
        end

        it 'succeeds if the process is not web' do
          process.type = 'not-webish'

          expect(process.instances).to eq(1)
          expect(process.memory).to eq(1024)
          expect(process.disk_quota).to eq(50)
          expect(process.log_quota).to eq(1_048_576)

          process_scale.scale

          expect(process.reload.instances).to eq(2)
          expect(process.reload.memory).to eq(100)
          expect(process.reload.disk_quota).to eq(200)
          expect(process.reload.log_quota).to eq(409_600)
        end

        it 'fails if the process is web' do
          process.type = 'web'

          expect(process.instances).to eq(1)
          expect(process.memory).to eq(1024)
          expect(process.disk_quota).to eq(50)
          expect(process.log_quota).to eq(1_048_576)

          expect { process_scale.scale }.to raise_error(ProcessScale::InvalidProcess, 'Cannot scale this process while a deployment is in flight.')

          expect(process.reload.instances).to eq(1)
          expect(process.reload.memory).to eq(1024)
          expect(process.reload.disk_quota).to eq(50)
          expect(process.reload.log_quota).to eq(1_048_576)
        end
      end
    end
  end
end
