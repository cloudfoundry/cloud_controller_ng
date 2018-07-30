require 'spec_helper'
require 'actions/app_update'
require 'actions/missing_process_create'

module VCAP::CloudController
  RSpec.describe SetCurrentDroplet do
    subject(:set_current_droplet) { SetCurrentDroplet.new(user_audit_info) }

    let(:app_model) { AppModel.make desired_state: ProcessModel::STOPPED }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
    let(:current_process_types) { double(:current_process_types) }

    describe '#update_to' do
      let(:droplet) do
        DropletModel.make(
          state: DropletModel::STAGED_STATE,
          process_types: { web: 'x' },
          app: app_model
        )
      end
      let(:droplet_guid) { droplet.guid }
      let(:message) { { 'droplet_guid' => droplet_guid } }

      before do
        app_model.add_droplet_by_guid(droplet_guid)
        allow(MissingProcessCreate).to receive(:new).with(user_audit_info).and_return(current_process_types)
        allow(current_process_types).to receive(:create_from_current_droplet).with(app_model)
      end

      it 'sets the desired droplet guid' do
        updated_app = set_current_droplet.update_to(app_model, droplet)
        expect(updated_app.droplet_guid).to eq(droplet_guid)
        expect(current_process_types).to have_received(:create_from_current_droplet).once
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_map_droplet).with(
          app_model,
          app_model.space,
          user_audit_info,
          { droplet_guid: droplet.guid }
        )

        set_current_droplet.update_to(app_model, droplet)
      end

      it 're-raises validation errors' do
        allow(app_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('invalid'))
        expect {
          set_current_droplet.update_to(app_model, droplet)
        }.to raise_error(SetCurrentDroplet::InvalidApp)
      end

      describe 'error cases' do
        context 'when the droplet is not associated with the application' do
          it 'raises an error' do
            other_droplet = DropletModel.make
            expect {
              set_current_droplet.update_to(app_model, other_droplet)
            }.to raise_error SetCurrentDroplet::Error, 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
          end
        end

        context 'when the droplet does not exist' do
          it 'raises an error' do
            expect {
              set_current_droplet.update_to(app_model, nil)
            }.to raise_error SetCurrentDroplet::Error, 'Unable to assign current droplet. Ensure the droplet exists and belongs to this app.'
          end
        end
      end
    end
  end
end
