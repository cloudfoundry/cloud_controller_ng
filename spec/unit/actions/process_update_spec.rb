require 'spec_helper'
require 'actions/process_update'

module VCAP::CloudController
  RSpec.describe ProcessUpdate do
    subject(:process_update) { ProcessUpdate.new(user_guid, user_email) }

    let(:health_check) do
      {
        'type' => 'process',
        'data' => {
          'timeout' => 20
        }
      }
    end
    let(:message) { ProcessUpdateMessage.new({ command: 'new', health_check: health_check, ports: [1234, 5678] }) }
    let!(:process) do
      App.make(
        :process,
        command:              'initial command',
        health_check_type:    'port',
        health_check_timeout: 10,
        ports:                [1574, 3389]
      )
    end
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }

    describe '#update' do
      it 'updates the requested changes on the process' do
        process_update.update(process, message)

        process.reload
        expect(process.command).to eq('new')
        expect(process.health_check_type).to eq('process')
        expect(process.health_check_timeout).to eq(20)
        expect(process.ports).to match_array([1234, 5678])
      end

      context 'when no changes are requested' do
        let(:message) { ProcessUpdateMessage.new({}) }

        it 'does not update the process' do
          process_update.update(process, message)

          process.reload
          expect(process.command).to eq('initial command')
          expect(process.health_check_type).to eq('port')
          expect(process.health_check_timeout).to eq(10)
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

          process.reload
          expect(process.health_check_type).to eq('process')
          expect(process.health_check_timeout).to eq(10)
        end
      end

      it 'creates an audit event' do
        expect(Repositories::ProcessEventRepository).to receive(:record_update).with(
          process,
          user_guid,
          user_email,
          {
            'command'      => 'new',
            'ports'        => [1234, 5678],
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
