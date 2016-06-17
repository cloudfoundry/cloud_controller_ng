require 'spec_helper'
require 'actions/process_terminate'

module VCAP::CloudController
  RSpec.describe ProcessTerminate do
    subject(:process_terminate) { ProcessTerminate.new(user_guid, user_email, process, index) }
    let(:app) { AppModel.make }
    let!(:process) { AppFactory.make(app: app) }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }
    let(:index) { 0 }

    let(:index_stopper) { double(IndexStopper, stop_index: true) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:index_stopper).and_return(index_stopper)
    end

    describe '#terminate' do
      it 'terminates the process instance' do
        expect(process.instances).to eq(1)
        process_terminate.terminate
        expect(index_stopper).to have_received(:stop_index).with(process, 0)
      end

      it 'creates an audit event' do
        expect(Repositories::ProcessEventRepository).to receive(:record_terminate).with(
          process,
          user_guid,
          user_email,
          index
        )
        process_terminate.terminate
      end

      context 'when index is greater than the number of process instances' do
        let(:index) { 6 }

        it 'raises InstanceNotFound' do
          expect {
            process_terminate.terminate
          }.to raise_error(ProcessTerminate::InstanceNotFound)
        end
      end
    end
  end
end
