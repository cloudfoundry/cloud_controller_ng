require 'spec_helper'

module VCAP::CloudController
  describe AppCreate do
    subject(:app_create) { AppCreate.new }

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
    end
  end
end
