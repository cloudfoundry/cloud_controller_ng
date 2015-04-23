require 'spec_helper'
require 'actions/process_scale'

module VCAP::CloudController
  describe ProcessScale do
    subject(:process_scale) { ProcessScale.new(user, user_email) }
    let(:message) { ProcessScaleMessage.new({ instances: 2 }) }
    let!(:process) { AppFactory.make }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    describe '#scale' do
      it 'scales the process record' do
        expect(process.instances).not_to eq(2)

        process_scale.scale(process, message)

        expect(process.reload.instances).to eq(2)
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_update).with(
          process,
            process.space,
            user.guid,
            user_email,
            {
              'instances' => 2
            }
        )

        process_scale.scale(process, message)
      end

      context 'when the process is invalid' do
        before do
          allow(process).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an invalid error' do
          expect {
            process_scale.scale(process, message)
          }.to raise_error(ProcessScale::InvalidProcess, 'the message')
        end
      end
    end
  end
end
