require 'spec_helper'
require 'handlers/procfile_handler'

module VCAP::CloudController
  describe ProcfileHandler do
    let(:apps_handler) { AppsHandler.new(double(:packages_handler), double(:droplets_handler), processes_handler) }
    let(:processes_handler) { ProcessesHandler.new(ProcessRepository.new, Repositories::Runtime::AppEventRepository.new) }
    let(:procfile_handler) { described_class.new(apps_handler, processes_handler) }
    let(:access_context) { double(:access_context, user: User.make, user_email: 'jim@jim.com', roles: double(:roles, admin?: true)) }

    before do
      allow(access_context).to receive(:cannot?).and_return(false)
    end

    describe '#process_procfile' do
      let(:app_model) { AppModel.make }
      let(:guid) { app_model.guid }
      let(:procfile) do
        {
          web: 'thing',
          other: 'stuff',
        }
      end

      context 'when the user cannot update the app' do
        before do
          allow(access_context).to receive(:cannot?).and_return(true)
        end

        it 'raises Unauthorized' do
          expect {
            procfile_handler.process_procfile(app_model, procfile, access_context)
          }.to raise_error(ProcfileHandler::Unauthorized)
          expect(access_context).to have_received(:cannot?).with(:update, app_model)
        end
      end

      context 'when an app had a process type that is no longer mentioned' do
        before do
          existing_process = AppFactory.make(type: 'bogus', command: 'old')
          app_model.add_process_by_guid(existing_process.guid)
        end

        it 'deletes the process' do
          allow(access_context).to receive(:can?).and_return(true)
          process = App.where(app_guid: guid, type: 'bogus').first
          procfile_handler.process_procfile(app_model, procfile, access_context)
          expect {
            process.refresh
          }.to raise_error(Sequel::Error)
        end
      end

      context 'when the app already has a process with the same type' do
        before do
          existing_process = AppFactory.make(type: 'web', command: 'old')
          app_model.add_process_by_guid(existing_process.guid)
        end

        it 'updates the process' do
          process = App.where(app_guid: guid, type: 'web').first
          expect {
            procfile_handler.process_procfile(app_model, procfile, access_context)
          }.to change { process.refresh.command }.from('old').to('thing')
        end
      end

      context 'when a user can process procfiles' do
        it 'adds the process' do
          expect(app_model.processes.count).to eq(0)

          procfile_handler.process_procfile(app_model, procfile, access_context)

          app_model.reload
          expect(app_model.processes.count).to eq(2)
        end
      end
    end
  end
end
