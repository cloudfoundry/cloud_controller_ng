require 'spec_helper'
require 'actions/app_update'
require 'actions/process_create_from_app_droplet'

module VCAP::CloudController
  RSpec.describe AppAssignDroplet do
    subject(:app_assign_droplet) { AppAssignDroplet.new(user_audit_info) }

    let(:app_model) { AppModel.make desired_state: ProcessModel::STOPPED }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:process_create_from_app_droplet) { double(:process_create_from_app_droplet) }

    describe '#assign' do
      let(:droplet) do
        DropletModel.make(
          state: DropletModel::STAGED_STATE,
          process_types: { web: 'x' },
          sidecars: [{ name: 'sleep infinity', command: 'sleep infinity', process_types: ['web'] }],
          app: app_model
        )
      end
      let(:droplet_guid) { droplet.guid }
      let(:message) { { 'droplet_guid' => droplet_guid } }

      before do
        app_model.add_droplet_by_guid(droplet_guid)
        allow(ProcessCreateFromAppDroplet).to receive(:new).with(user_audit_info).and_return(process_create_from_app_droplet)
        allow(process_create_from_app_droplet).to receive(:create).with(app_model)

        allow(SidecarSynchronizeFromAppDroplet).to receive(:synchronize).with(app_model)
      end

      it 'sets the desired droplet guid' do
        updated_app = app_assign_droplet.assign(app_model, droplet)

        expect(updated_app.droplet_guid).to eq(droplet_guid)
      end

      it 'creates processes from the droplet' do
        app_assign_droplet.assign(app_model, droplet)

        expect(process_create_from_app_droplet).to have_received(:create).once
      end

      it 'creates sidecars from the droplet' do
        app_assign_droplet.assign(app_model, droplet)

        expect(SidecarSynchronizeFromAppDroplet).to have_received(:synchronize).once
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_map_droplet).with(
          app_model,
          app_model.space,
          user_audit_info,
          { droplet_guid: droplet.guid }
        )

        app_assign_droplet.assign(app_model, droplet)
      end

      it 're-raises validation errors' do
        allow(app_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('invalid'))
        expect {
          app_assign_droplet.assign(app_model, droplet)
        }.to raise_error(AppAssignDroplet::InvalidApp)
      end

      describe 'error cases' do
        context 'when the droplet is not associated with the application' do
          it 'raises an error' do
            other_droplet = DropletModel.make
            expect {
              app_assign_droplet.assign(app_model, other_droplet)
            }.to raise_error AppAssignDroplet::InvalidDroplet, 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
          end
        end

        context 'when the droplet does not exist' do
          it 'raises an error' do
            expect {
              app_assign_droplet.assign(app_model, nil)
            }.to raise_error AppAssignDroplet::InvalidDroplet, 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
          end
        end

        context 'when we fail to create missing processes' do
          before do
            allow(process_create_from_app_droplet).to receive(:create).and_raise(ProcessCreateFromAppDroplet::ProcessTypesNotFound, 'some message')
          end

          it 'raises an error' do
            expect {
              app_assign_droplet.assign(app_model, droplet)
            }.to raise_error AppAssignDroplet::InvalidDroplet, 'some message'
          end
        end

        context 'when we fail to create missing processes' do
          before do
            allow(process_create_from_app_droplet).to receive(:create).and_raise(SidecarSynchronizeFromAppDroplet::ConflictingSidecarsError, 'some message')
          end

          it 'raises an error' do
            expect {
              app_assign_droplet.assign(app_model, droplet)
            }.to raise_error AppAssignDroplet::InvalidDroplet, 'some message'
          end
        end

        context 'when we fail to allocate enough memory to go with existing sidecars' do
          before do
            allow(process_create_from_app_droplet).to receive(:create).and_raise(ProcessCreate::SidecarMemoryLessThanProcessMemory, 'some message')
          end

          it 'raises an error' do
            expect {
              app_assign_droplet.assign(app_model, droplet)
            }.to raise_error AppAssignDroplet::InvalidApp, 'some message'
          end
        end
      end
    end
  end
end
