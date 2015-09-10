require 'spec_helper'
require 'actions/procfile_parse'

module VCAP::CloudController
  describe ProcfileParse do
    let(:user) { double(:user, guid: Sham.guid) }
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet) }
    subject(:procfile_parse) { ProcfileParse.new(user.guid, Sham.email) }

    describe '#process_procfile' do
      context 'when the apps droplet has a procfile' do
        let(:procfile) do
          <<-PROCFILE
web: thing
other: stuff
          PROCFILE
        end
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, procfile: procfile) }

        it 'adds missing processes' do
          expect(app.processes.count).to eq(0)
          procfile_parse.process_procfile(app)

          app.reload
          expect(app.processes.count).to eq(2)
        end

        context 'when adding processes it sets the default instance count' do
          context 'web processes' do
            let(:procfile) do
              <<-PROCFILE
web: thing
              PROCFILE
            end

            it '1 instance' do
              procfile_parse.process_procfile(app)
              app.reload

              expect(app.processes[0].instances).to eq(1)
            end
          end

          context 'non-web processes' do
            let(:procfile) do
              <<-PROCFILE
other: stuff
              PROCFILE
            end

            it '0 instances' do
              procfile_parse.process_procfile(app)
              app.reload

              expect(app.processes[0].instances).to eq(0)
            end
          end
        end

        it 'deletes processes that are no longer mentioned' do
          existing_process = AppFactory.make(type: 'bogus', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'bogus').first
          procfile_parse.process_procfile(app)

          expect {
            process.refresh
          }.to raise_error(Sequel::Error)
        end

        it 'updates existing processes' do
          existing_process = AppFactory.make(type: 'other', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'other').first

          expect {
            procfile_parse.process_procfile(app)
          }.to change { process.refresh.command }.from('old').to('stuff')
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
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, procfile: nil) }
        let(:app) { AppModel.make(droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            procfile_parse.process_procfile(app)
          }.to raise_error(ProcfileParse::ProcfileNotFound)
        end
      end
    end
  end
end
