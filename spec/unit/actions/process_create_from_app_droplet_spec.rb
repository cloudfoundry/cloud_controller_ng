require 'spec_helper'
require 'actions/process_create_from_app_droplet'

module VCAP::CloudController
  RSpec.describe ProcessCreateFromAppDroplet do
    let(:droplet) { nil }
    let(:app) { FactoryBot.create(:app, droplet: droplet, name: 'my_app') }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
    subject { ProcessCreateFromAppDroplet.new(user_audit_info) }

    describe '#create' do
      let(:process_types) { { web: 'thing', other: 'stuff' } }
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

      context 'when the app has a droplet that has a process type' do
        it 'creates missing processes without setting their commands' do
          expect(app.processes.count).to eq(0)
          subject.create(app)

          app.reload
          expect(app.processes.count).to eq(2)
          expect(app.processes[0].command).to be_nil
          expect(app.processes[1].command).to be_nil
        end

        it 'does not delete existing processes' do
          existing_process = ProcessModel.make(type: 'manifest-born-process', app: app)

          subject.create(app)

          expect(existing_process.exists?).to be true
        end

        it 'does not update the process’s command' do
          existing_process = ProcessModel.make(type: 'other', command: 'old', app: app, metadata: {})
          expect {
            subject.create(app)
          }.not_to change { existing_process.refresh.command }
        end
      end

      context 'when the app does not have droplet' do
        let(:droplet) { nil }

        it 'raises a ProcessTypesNotFound error' do
          expect {
            subject.create(app)
          }.to raise_error(ProcessCreateFromAppDroplet::ProcessTypesNotFound)
        end
      end

      context 'when the app has a droplet, but the droplet does not have a process type' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: nil) }
        let(:app) { FactoryBot.create(:app, droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            subject.create(app)
          }.to raise_error(ProcessCreateFromAppDroplet::ProcessTypesNotFound)
        end
      end
    end
  end
end
