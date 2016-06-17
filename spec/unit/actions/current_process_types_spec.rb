require 'spec_helper'
require 'actions/current_process_types'

module VCAP::CloudController
  RSpec.describe CurrentProcessTypes do
    let(:user) { double(:user, guid: Sham.guid) }
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet, name: 'my_app') }
    subject(:current_process_types) { CurrentProcessTypes.new(user.guid, Sham.email) }

    describe '#process_current_droplet' do
      let(:process_types) { { web: 'thing', other: 'stuff' } }
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

      it 'adds missing processes' do
        expect(app.processes.count).to eq(0)
        current_process_types.process_current_droplet(app)

        app.reload
        expect(app.processes.count).to eq(2)
      end

      it 'deletes processes that are no longer mentioned' do
        process_to_delete = App.make(type: 'bogus', space: app.space, app: app)

        current_process_types.process_current_droplet(app)

        expect(process_to_delete.exists?).to be_falsey
      end

      it 'updates existing processes' do
        existing_process = AppFactory.make(type: 'other', command: 'old', space: app.space, app: app)
        expect {
          current_process_types.process_current_droplet(app)
        }.to change { existing_process.refresh.command }.from('old').to('stuff')
      end

      context 'when the app does not have droplet' do
        let(:droplet) { nil }

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
