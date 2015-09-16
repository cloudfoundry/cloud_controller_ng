require 'spec_helper'
require 'actions/process_update'

module VCAP::CloudController
  describe ProcessUpdate do
    subject(:process_update) { ProcessUpdate.new(user, user_email) }
    let(:message) { ProcessUpdateMessage.new({ command: 'new' }) }
    let!(:process) { AppFactory.make }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    describe '#update' do
      it 'updates the process record' do
        expect(process.command).not_to eq('new')

        process_update.update(process, message)

        expect(process.reload.command).to eq('new')
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_update).with(
          process,
            process.space,
            user.guid,
            user_email,
            {
              'command' => 'new'
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
