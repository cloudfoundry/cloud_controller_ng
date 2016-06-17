require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  RSpec.describe SetCurrentDroplet do
    let(:app_model) { AppModel.make }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:set_current_droplet) { SetCurrentDroplet.new(user, user_email) }
    let(:current_process_types) { double(:current_process_types) }

    describe '.update_to' do
      let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, process_types: { web: 'x' }) }
      let(:droplet_guid) { droplet.guid }
      let(:message) { { 'droplet_guid' => droplet_guid } }

      before do
        app_model.add_droplet_by_guid(droplet_guid)
        allow(CurrentProcessTypes).to receive(:new).with(user.guid, user_email).and_return(current_process_types)
        allow(current_process_types).to receive(:process_current_droplet).with(app_model)
      end

      it 'sets the desired droplet guid' do
        updated_app = set_current_droplet.update_to(app_model, droplet)
        expect(updated_app.droplet_guid).to eq(droplet_guid)
        expect(current_process_types).to have_received(:process_current_droplet).once
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_map_droplet).with(
          app_model,
          app_model.space,
          user.guid,
          user_email,
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
    end
  end
end
