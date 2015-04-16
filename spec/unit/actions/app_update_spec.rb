require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  describe AppUpdate do
    let(:app_model) { AppModel.make }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:app_update) { AppUpdate.new(user, user_email) }

    describe '.update' do
      let(:message) { { 'update_message' => 'update_message' } }

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_update).with(
          app_model,
          app_model.space,
          user.guid,
          user_email,
          message
        )

        app_update.update(app_model, message)
      end

      context 'when given a new name' do
        let(:name) { 'new name' }
        let(:message) { { 'name' => name } }

        it 'updates the app name' do
          app_update.update(app_model, message)
          app_model.reload

          expect(app_model.name).to eq(name)
        end
      end

      context 'when updating the environment variables' do
        let(:environment_variables) { { 'VARIABLE' => 'VALUE' } }
        let(:message) { { 'environment_variables' => environment_variables } }

        it 'updates the app environment variables' do
          app_update.update(app_model, message)
          app_model.reload

          expect(app_model.environment_variables).to eq(environment_variables)
        end
      end

      context 'when the app is invalid' do
        let(:name) { 'new name' }
        let(:message) { { 'name' => name } }

        before do
          allow(app_model).to receive(:save).and_raise(Sequel::ValidationFailed.new('something'))
        end

        it 'raises an invalid app error' do
          expect { app_update.update(app_model, message) }.to raise_error(AppUpdate::InvalidApp)
        end
      end
    end
  end
end
