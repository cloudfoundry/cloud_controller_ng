require 'spec_helper'
require 'actions/procfile_parse'

module VCAP::CloudController
  describe ProcfileParse do
    let(:user) { double(:user, guid: Sham.guid) }
    let(:droplet) { nil }
    let(:app) { AppModel.make(desired_droplet: droplet) }
    subject(:procfile_parse) { ProcfileParse.new(user, Sham.email) }

    def last_event
      Event.last
    end

    describe '#process_procfile' do
      context 'when the apps droplet has a procfile' do
        let(:procfile) do
          <<-PROCFILE
web: thing
other: stuff
          PROCFILE
        end
        let(:droplet) { DropletModel.make(procfile: procfile) }

        it 'adds missing processes' do
          expect(app.processes.count).to eq(0)
          procfile_parse.process_procfile(app)

          app.reload
          expect(app.processes.count).to eq(2)
          expect(last_event.actee_type).to eq('app')
          expect(last_event.actor).to eq(user.guid)
          expect(last_event.type).to eq('audit.app.create')
        end

        it 'deletes processes that are no longer mentioned' do
          existing_process = AppFactory.make(type: 'bogus', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'bogus').first
          procfile_parse.process_procfile(app)

          expect {
            process.refresh
          }.to raise_error(Sequel::Error)

          expect(last_event.actee_type).to eq('app')
          expect(last_event.actor).to eq(user.guid)
          expect(last_event.type).to eq('audit.app.delete-request')
        end

        it 'updates existing processes' do
          existing_process = AppFactory.make(type: 'other', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'other').first

          expect {
            procfile_parse.process_procfile(app)
          }.to change { process.refresh.command }.from('old').to('stuff')

          expect(last_event.actee_type).to eq('app')
          expect(last_event.actor).to eq(user.guid)
          expect(last_event.type).to eq('audit.app.update')
        end
      end

      context 'when the app does not have droplet' do
        it 'raises a ProcfileNotFound error' do
          expect {
            procfile_parse.process_procfile(app)
          }.to raise_error(ProcfileParse::ProcfileNotFound)
        end
      end

      context 'when the app has a droplet, but the droplet does not have a procfile' do
        let(:droplet) { DropletModel.make(procfile: nil) }
        let(:app) { AppModel.make(desired_droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            procfile_parse.process_procfile(app)
          }.to raise_error(ProcfileParse::ProcfileNotFound)
        end
      end
    end
  end
end
