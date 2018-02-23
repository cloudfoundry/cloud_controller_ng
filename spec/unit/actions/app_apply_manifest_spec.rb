require 'spec_helper'
require 'actions/app_apply_manifest'

module VCAP::CloudController
  RSpec.describe AppApplyManifest do
    subject(:app_apply_manifest) { AppApplyManifest.new(user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo) }
    let(:process_scale) { instance_double(ProcessScale) }

    describe '#apply' do
      before do
        allow(ProcessScale).
          to receive(:new).with(user_audit_info, process, process_scale_message).and_return(process_scale)
        allow(process_scale).to receive(:scale)
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

        context 'when the request is invalid' do
          let(:message) { AppManifestMessage.new({ name: 'blah', instances: -1 }) }

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

        context 'when the request is invalid' do
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
    end
  end
end
