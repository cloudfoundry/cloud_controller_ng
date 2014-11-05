require 'spec_helper'

module VCAP::CloudController

  describe ProcessCreator do
    let(:process) { instance_double(AppProcess) }
    let(:process_repo) { instance_double(ProcessRepository) }
    let(:access_context) { instance_double(AppProcessAccess) }
    subject(:process_creator) { ProcessCreator.new(process_repo, access_context) }

    describe '#create' do
      context 'when the user cannot access the process' do
        before do
          allow(process_repo).to receive(:new_process).and_return(process)
          allow(access_context).to receive(:cannot?).with(:create, process).and_return(true)
        end

        it 'raises a UnauthorizedError' do
          expect {
            process_creator.create({})
          }.to raise_error ProcessCreator::UnauthorizedError
        end
      end
    end
  end
end
