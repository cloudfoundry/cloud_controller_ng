require 'spec_helper'
require 'messages/apps/app_create_message'
require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'

module VCAP::CloudController
  RSpec.describe AppCreate do
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'gooid', user_guid: 'amelia@cats.com') }

    subject(:app_create) { AppCreate.new(user_audit_info) }

    describe '#create' do
      let(:space) { Space.make }
      let(:space_guid) { space.guid }
      let(:environment_variables) { { BAKED: 'POTATO' } }
      let(:buildpack) { Buildpack.make }
      let(:relationships) { { space: { data: { guid: space_guid } } } }
      let(:lifecycle_request) { { type: 'buildpack', data: { buildpacks: [buildpack.name], stack: 'cflinuxfs2' } } }
      let(:lifecycle) { instance_double(AppBuildpackLifecycle, create_lifecycle_data_model: nil) }

      context 'when the request is valid' do
        let(:message) do
          AppCreateMessage.new(
            {
              name: 'my-app',
              relationships: relationships,
              environment_variables: environment_variables,
              lifecycle: lifecycle_request
            })
        end

        before { expect(message).to be_valid }

        it 'creates an app' do
          app = app_create.create(message, lifecycle)

          expect(app.name).to eq('my-app')
          expect(app.space).to eq(space)
          expect(app.environment_variables).to eq(environment_variables.stringify_keys)

          expect(lifecycle).to have_received(:create_lifecycle_data_model).with(app)
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::AppEventRepository).
            to receive(:record_app_create).with(instance_of(AppModel),
              space,
              user_audit_info,
              message.audit_hash
            )

          app_create.create(message, lifecycle)
        end
      end

      it 're-raises validation errors' do
        message = AppCreateMessage.new('name' => '', relationships: relationships)
        expect {
          app_create.create(message, lifecycle)
        }.to raise_error(AppCreate::InvalidApp)
      end
    end
  end
end
