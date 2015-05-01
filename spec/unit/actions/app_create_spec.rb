require 'spec_helper'
require 'messages/app_create_message'

module VCAP::CloudController
  describe AppCreate do
    let(:user) { double(:user, guid: 'single') }
    let(:user_email) { 'user-email' }
    subject(:app_create) { AppCreate.new(user, user_email) }

    describe '#create' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid }
      let(:environment_variables) { { 'BAKED' => 'POTATO' } }

      it 'create an app' do
        message = AppCreateMessage.new(name: 'my-app', space_guid: space_guid, environment_variables: environment_variables)
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
        message = AppCreateMessage.new(name: 'my-app', space_guid: space_guid, environment_variables: environment_variables)
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_create).with(
            instance_of(AppModel),
            space,
            user.guid,
            user_email,
            message.as_json
          )

        app_create.create(message)
      end
    end
  end
end
