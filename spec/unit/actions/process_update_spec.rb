require 'spec_helper'
require 'actions/process_update'

module VCAP::CloudController
  RSpec.describe ProcessUpdate do
    subject(:process_update) { ProcessUpdate.new(user_audit_info) }

    let(:health_check) do
      {
        type: 'process',
        data: { timeout: 20 }
      }
    end
    let(:message) { ProcessUpdateMessage.new({ command: 'new', health_check: health_check }) }
    let!(:process) do
      ProcessModel.make(
        :process,
        command:              'initial command',
        health_check_type:    'port',
        health_check_timeout: 10,
        ports:                [1574, 3389]
      )
    end
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }

    describe '#update' do
      it 'updates the requested changes on the process' do
        process_update.update(process, message)

        process.reload
        expect(process.command).to eq('new')
        expect(process.health_check_type).to eq('process')
        expect(process.health_check_timeout).to eq(20)
      end

      context 'when the new healthcheck is http' do
        let(:health_check) do
          {
            type: 'http',
            data: { endpoint: '/healthcheck' }
          }
        end

        it 'updates the requested changes on the process' do
          process_update.update(process, message)

          process.reload
          expect(process.command).to eq('new')
          expect(process.health_check_type).to eq('http')
          expect(process.health_check_http_endpoint).to eq('/healthcheck')
        end
      end

      context 'when the old healthcheck is http and the new healtcheck is not' do
        let!(:process) do
          ProcessModel.make(
            :process,
            command:              'initial command',
            health_check_type:    'http',
            health_check_http_endpoint: '/healthcheck',
            health_check_timeout: 10,
            ports:                [1574, 3389]
          )
        end

        let(:health_check) do
          {
            type: 'port',
          }
        end

        it 'clears the HTTP endpoint field' do
          process_update.update(process, message)

          process.reload
          expect(process.command).to eq('new')
          expect(process.health_check_type).to eq('port')
          expect(process.health_check_http_endpoint).to be_nil
        end
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
            type: 'process',
            data: {}
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
          user_audit_info,
          {
            'command'      => 'new',
            'health_check' => {
              type: 'process',
              data: { timeout: 20 }
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
