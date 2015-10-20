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
      let(:buildpack) { Buildpack.make }
      let(:relationships) { { 'space' => { 'guid' => space_guid } } }
      let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack.name, 'stack' => 'cflinuxfs2' } } }

      context 'when the request is valid' do
        let(:message) do
          AppCreateMessage.new(name: 'my-app',
                               relationships: relationships,
                               environment_variables: environment_variables,
                               lifecycle: lifecycle)
        end

        before { expect(message).to be_valid }

        it 'creates an app' do
          app = app_create.create(message)

          expect(app.name).to eq('my-app')
          expect(app.space).to eq(space)
          expect(app.environment_variables).to eq(environment_variables)
          expect(app.lifecycle_data.buildpack).to eq(lifecycle['data']['buildpack'])
          expect(app.lifecycle_data.stack).to eq(lifecycle['data']['stack'])
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::Runtime::AppEventRepository).
            to receive(:record_app_create).with(instance_of(AppModel),
              space,
              user.guid,
              user_email,
              {
                'name'                  => 'my-app',
                'relationships'         => { 'space' => { 'guid' => space_guid } },
                'environment_variables' => { 'BAKED' => 'POTATO' },
                'lifecycle'             => lifecycle
              })

          app_create.create(message)
        end
      end

      it 're-raises validation errors' do
        message = AppCreateMessage.new('name' => '', relationships: relationships)
        expect {
          app_create.create(message)
        }.to raise_error(AppCreate::InvalidApp)
      end
    end
  end
end
