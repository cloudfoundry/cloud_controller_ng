require 'spec_helper'
require 'actions/current_process_types'

module VCAP::CloudController
  describe CurrentProcessTypes do
    let(:user) { double(:user, guid: Sham.guid) }
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet) }
    subject(:current_process_types) { CurrentProcessTypes.new(user.guid, Sham.email) }

    describe '#process_current_droplet' do
      context 'when the apps droplet has a procfile' do
        let(:process_types) do
          { web: 'thing', other: 'stuff' }
        end

        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

        it 'adds missing processes' do
          expect(app.processes.count).to eq(0)
          current_process_types.process_current_droplet(app)

          app.reload
          expect(app.processes.count).to eq(2)
        end

        context 'when adding processes it sets the default instance count' do
          context 'web processes' do
            let(:process_types) { { web: 'thing' } }

            it '1 instance' do
              current_process_types.process_current_droplet(app)
              app.reload

              expect(app.processes[0].instances).to eq(1)
            end
          end

          context 'non-web processes' do
            let(:process_types) { { other: 'stuff' } }

            it '0 instances' do
              current_process_types.process_current_droplet(app)
              app.reload

              expect(app.processes[0].instances).to eq(0)
            end
          end
        end

        it 'deletes processes that are no longer mentioned' do
          existing_process = AppFactory.make(type: 'bogus', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'bogus').first
          current_process_types.process_current_droplet(app)

          expect {
            process.refresh
          }.to raise_error(Sequel::Error)
        end

        it 'updates existing processes' do
          existing_process = AppFactory.make(type: 'other', command: 'old')
          app.add_process_by_guid(existing_process.guid)
          process = App.where(app_guid: app.guid, type: 'other').first

          expect {
            current_process_types.process_current_droplet(app)
          }.to change { process.refresh.command }.from('old').to('stuff')
        end
      end

      context 'when the app does not have droplet' do
        it 'raises a ProcessTypesNotFound error' do
          expect {
            current_process_types.process_current_droplet(app)
          }.to raise_error(CurrentProcessTypes::ProcessTypesNotFound)
        end
      end

      context 'when the app has a droplet, but the droplet does not have a process type' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: nil) }
        let(:app) { AppModel.make(droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            current_process_types.process_current_droplet(app)
          }.to raise_error(CurrentProcessTypes::ProcessTypesNotFound)
        end
      end
    end
  end
end
