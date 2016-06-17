require 'spec_helper'
require 'actions/process_scale'

module VCAP::CloudController
  RSpec.describe ProcessScale do
    subject(:process_scale) { ProcessScale.new(user, user_email, process, message) }
    let(:valid_message_params) { { instances: 2, memory_in_mb: 100, disk_in_mb: 200 } }
    let(:message) { ProcessScaleMessage.new(valid_message_params) }
    let(:app) { AppModel.make }
    let!(:process) { AppFactory.make(disk_quota: 50, app: app) }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    describe '#scale' do
      it 'scales the process record' do
        expect(process.instances).not_to eq(2)
        expect(process.memory).not_to eq(100)
        expect(process.disk_quota).not_to eq(200)

        process_scale.scale

        expect(process.reload.instances).to eq(2)
        expect(process.reload.memory).to eq(100)
        expect(process.reload.disk_quota).to eq(200)
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

      it 'creates a process audit event' do
        expect(Repositories::ProcessEventRepository).to receive(:record_scale).with(
          process,
            user.guid,
            user_email,
            {
              'instances'    => 2,
              'memory_in_mb' => 100,
              'disk_in_mb'   => 200
            }
        )

        process_scale.scale
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
    end
  end
end
