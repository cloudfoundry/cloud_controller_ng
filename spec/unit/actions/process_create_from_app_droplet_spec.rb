require 'spec_helper'
require 'actions/process_create_from_app_droplet'

module VCAP::CloudController
  RSpec.describe ProcessCreateFromAppDroplet do
    let(:droplet) { nil }
    let(:app) { AppModel.make(droplet: droplet, name: 'my_app') }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
    subject { ProcessCreateFromAppDroplet.new(user_audit_info) }

    describe '#create' do
      let(:process_types) { { web: 'thing', other: 'stuff' } }
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: process_types) }

      context 'when the app has a droplet that has a process type' do
        it 'creates missing processes without setting their commands' do
          expect(app.processes).to be_empty
          subject.create(app)

          app.reload
          expect(app.processes).to have_exactly(2).items
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

        context 'when the sidecar memory validation fails' do
          let!(:sidecar) { SidecarModel.make(app: app, name: 'my_sidecar', command: 'athenz', memory: 2000) }
          let!(:sidecar_process_type) { SidecarProcessTypeModel.make(sidecar: sidecar, type: 'other') }

          it 'translates the validation failure to a luxurious error' do
            expect {
              subject.create(app)
            }.to raise_error(
              ProcessCreate::SidecarMemoryLessThanProcessMemory,
              /The sidecar memory allocation defined is too large to run with the dependent "other" process/
            )
          end
        end

        context 'when non-sidecar validation fails' do
          before do
            errors = Sequel::Model::Errors.new
            errors.add(:something_important, 'is busted')
            allow_any_instance_of(VCAP::CloudController::ProcessCreate).to receive(:create).and_raise(Sequel::ValidationFailed.new(errors))
          end

          it 'raises the validation error' do
            expect {
              subject.create(app)
            }.to raise_error(Sequel::ValidationFailed)
          end
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
        let(:app) { AppModel.make(droplet: droplet) }

        it 'raises procfile not found' do
          expect {
            subject.create(app)
          }.to raise_error(ProcessCreateFromAppDroplet::ProcessTypesNotFound)
        end
      end
    end
  end
end
