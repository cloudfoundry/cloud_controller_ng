require 'spec_helper'
require 'actions/process_update'

module VCAP::CloudController
  describe ProcessUpdate do
    subject(:process_update) { ProcessUpdate.new(user, user_email) }

    let(:health_check) do
      {
        'type' => 'process',
        'data' => {
          'timeout' => 20
        }
      }
    end
    let(:message) { ProcessUpdateMessage.new({ command: 'new', health_check: health_check }) }
    let!(:process) { App.make(command: 'initial command', health_check_type: 'port', health_check_timeout: 10, metadata: {}) }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    describe '#update' do
      it 'updates the requested changes on the process' do
        process_update.update(process, message)

        expect(process.reload.command).to eq('new')
        expect(process.reload.health_check_type).to eq('process')
        expect(process.reload.health_check_timeout).to eq(20)
      end

      context 'when no changes are requested' do
        let(:message) { ProcessUpdateMessage.new({}) }

        it 'does not update the process' do
          process_update.update(process, message)

          expect(process.reload.command).to eq('initial command')
          expect(process.reload.health_check_type).to eq('port')
          expect(process.reload.health_check_timeout).to eq(10)
        end
      end

      context 'when partial health check update is requested' do
        let(:health_check) do
          {
            'type' => 'process',
            'data' => {}
          }
        end

        it 'updates just the requested information' do
          process_update.update(process, message)

          expect(process.reload.health_check_type).to eq('process')
          expect(process.reload.health_check_timeout).to eq(10)
        end
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_update).with(
          process,
          process.space,
          user.guid,
          user_email,
          {
            'command' => 'new',
            'health_check' => {
              'type' => 'process',
              'data' => {
                'timeout' => 20
              }
            }
          }
        )

        process_update.update(process, message)
      end

      context 'when the process is invalid' do
        before do
          allow(process).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an invalid error' do
          expect {
            process_update.update(process, message)
          }.to raise_error(ProcessUpdate::InvalidProcess, 'the message')
        end
      end
    end
  end
end
