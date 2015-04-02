require 'spec_helper'

module VCAP::CloudController
  describe AppCreate do
    let(:user) { double(:user, guid: 'single') }
    subject(:app_create) { AppCreate.new(user, 'quotes') }

    describe '#create' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid }
      let(:environment_variables) { { 'BAKED' => 'POTATO' } }

      it 'create an app' do
        message = AppCreateMessage.new('name' => 'my-app', 'space_guid' => space_guid, 'environment_variables' => environment_variables)
        app = app_create.create(message)
        expect(app.name).to eq('my-app')
        expect(app.space).to eq(space)
        expect(app.environment_variables).to eq(environment_variables)
      end

      it 're-raises validation errors' do
        message = AppCreateMessage.new('name' => '', 'space_guid' => space_guid)
        expect {
          app_create.create(message)
        }.to raise_error(AppCreate::InvalidApp)
      end

      it 'creates an audit event' do
        message = AppCreateMessage.new('name' => 'my-app', 'space_guid' => space_guid, 'environment_variables' => environment_variables)
        app = app_create.create(message)
        event = Event.last
        expect(event.type).to eq('audit.app.create')
        expect(event.actor).to eq('single')
        expect(event.actor_name).to eq('quotes')
        expect(event.actee_type).to eq('v3-app')
        expect(event.actee).to eq(app.guid)
      end
    end
  end
end
