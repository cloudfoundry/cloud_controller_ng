require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  describe SetCurrentDroplet do
    let(:app_model) { AppModel.make }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:set_current_droplet) { SetCurrentDroplet.new(user, user_email) }
    let(:procfile_parse) { double(:procfile_parse) }

    describe '.update_to' do
      let(:droplet) { DropletModel.make(procfile: 'web: x') }
      let(:droplet_guid) { droplet.guid }
      let(:message) { { 'desired_droplet_guid' => droplet_guid } }

      before do
        app_model.add_droplet_by_guid(droplet_guid)
        allow(set_current_droplet).to receive(:procfile_parse).and_return(procfile_parse)
        allow(procfile_parse).to receive(:process_procfile).with(app_model)
      end

      it 'sets the desired droplet guid' do
        updated_app = set_current_droplet.update_to(app_model, droplet)
        expect(updated_app.desired_droplet_guid).to eq(droplet_guid)
        expect(procfile_parse).to have_received(:process_procfile).once
      end

      it 'creates an audit event' do
        set_current_droplet.update_to(app_model, droplet)

        event = Event.where(actor: '1337').first
        expect(event.type).to eq('audit.app.update')
        expect(event.actor).to eq('1337')
        expect(event.actor_name).to eq(user_email)
        expect(event.actee_type).to eq('v3-app')
        expect(event.actee).to eq(app_model.guid)
        expect(event.metadata['updated_fields']).to include('desired_droplet_guid')
      end
    end
  end
end
