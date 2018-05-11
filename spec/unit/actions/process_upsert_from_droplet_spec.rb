require 'spec_helper'
require 'actions/process_upsert_from_droplet'

module VCAP::CloudController
  RSpec.describe ProcessUpsertFromDroplet do
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet, name: 'my_app') }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
    subject(:process_upsert_from_droplet) { ProcessUpsertFromDroplet.new(user_audit_info) }

    describe '#process_current_droplet' do
      let(:process_types) { { web: 'thing', other: 'stuff' } }
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

      it 'creates missing processes' do
        expect(app.processes.count).to eq(0)
        process_upsert_from_droplet.process_current_droplet(app)

        app.reload
        expect(app.processes.count).to eq(2)

        process_create_events = Event.last(2)
        expect(process_create_events.map(&:type)).to match_array(['audit.app.process.create', 'audit.app.process.create'])
      end

      it 'does not delete existing processes' do
        existing_process = ProcessModel.make(type: 'manifest-born-process', app: app)

        process_upsert_from_droplet.process_current_droplet(app)

        expect(existing_process.exists?).to be true
      end

      context 'when updating existing processes' do
        let(:process_types) { { other: 'stuff' } }
        let!(:existing_process) { ProcessModel.make(type: 'other', command: 'old', app: app, metadata: {}) }

        it 'updates the detected command for existing processes without changing command' do
          updated_process_types = { web: 'thing', other: 'newer-stuff' }

          expect {
            new_droplet = DropletModel.make(state: DropletModel::STAGED_STATE, process_types: updated_process_types)
            app.update(droplet: new_droplet)
            process_upsert_from_droplet.process_current_droplet(app)
          }.to change { existing_process.refresh.detected_start_command }.from('stuff').to('newer-stuff')

          expect(existing_process.command).to eq('old')
        end

        it 'creates an empty process.update audit event so users know what processes were affected' do
          expect {
            process_upsert_from_droplet.process_current_droplet(app)
          }.to change { Event.count }.by(1)

          process_update_event = Event.last
          expect(process_update_event.type).to eq('audit.app.process.update')
        end
      end

      context 'when the app does not have droplet' do
        let(:droplet) { nil }

        it 'raises a ProcessTypesNotFound error' do
          expect {
            process_upsert_from_droplet.process_current_droplet(app)
          }.to raise_error(ProcessUpsertFromDroplet::ProcessTypesNotFound)
        end
      end

      context 'when the app has a droplet, but the droplet does not have a process type' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: nil) }
        let(:app) { AppModel.make(droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            process_upsert_from_droplet.process_current_droplet(app)
          }.to raise_error(ProcessUpsertFromDroplet::ProcessTypesNotFound)
        end
      end
    end
  end
end
