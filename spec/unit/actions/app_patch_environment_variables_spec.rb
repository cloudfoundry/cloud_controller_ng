require 'spec_helper'
require 'actions/app_patch_environment_variables'

module VCAP::CloudController
  RSpec.describe AppPatchEnvironmentVariables do
    subject(:app_update) { AppPatchEnvironmentVariables.new(user_audit_info) }

    let(:app_model) { AppModel.make(name: app_name, environment_variables: existing_environment_variables) }
    let(:user_guid) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }
    let(:app_name) { 'original name' }
    let(:existing_environment_variables) do
      {
        'override' => 'value-to-override',
        'preserve' => 'value-to-keep'
      }
    end

    describe '#patch' do
      let(:request_environment_variables) { { override: 'new-value' } }
      let(:message) do
        AppUpdateEnvironmentVariablesMessage.new({
          var: request_environment_variables,
        })
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_update).with(
          app_model,
          app_model.space,
          user_audit_info,
          { 'environment_variables' => request_environment_variables },
        )

        app_update.patch(app_model, message)
      end

      it 'patches the apps environment_variables' do
        expect(app_model.environment_variables).to eq(existing_environment_variables)

        app_update.patch(app_model, message)
        app_model.reload

        expect(app_model.environment_variables).to eq({
          'override' => 'new-value',
          'preserve' => 'value-to-keep',
        })
      end

      context 'when the app does not have any existing environment variables' do
        let(:existing_environment_variables) do
          nil
        end
        it 'patches the apps environment_variables' do
          expect(app_model.environment_variables).to eq(existing_environment_variables)

          app_update.patch(app_model, message)
          app_model.reload

          expect(app_model.environment_variables).to eq({
            'override' => 'new-value',
          })
        end
      end

      context 'when a requested environment variable has a nil value' do
        let(:request_environment_variables) { { override: nil } }

        it 'removes the environment variable' do
          expect(app_model.environment_variables).to eq(existing_environment_variables)

          app_update.patch(app_model, message)
          app_model.reload

          expect(app_model.environment_variables).to eq({
            'preserve' => 'value-to-keep',
          })
        end
      end

      context 'when a environment variable hash is empty' do
        let(:request_environment_variables) { {} }

        it 'should not change the apps environment variables' do
          expect(app_model.environment_variables).to eq(existing_environment_variables)

          app_update.patch(app_model, message)
          app_model.reload

          expect(app_model.environment_variables).to eq(existing_environment_variables)
        end
      end
    end
  end
end
