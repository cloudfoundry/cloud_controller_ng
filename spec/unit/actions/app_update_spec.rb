require 'spec_helper'
require 'actions/app_update'

module VCAP::CloudController
  describe AppUpdate do
    let(:app_model) { AppModel.make }
    let(:user) { double(:user, guid: '1337') }
    let(:user_email) { 'cool_dude@hoopy_frood.com' }
    let(:app_update) { AppUpdate.new(user, user_email) }

    describe '.update' do
      context 'when given a new name' do
        let(:name) { 'new name' }
        let(:message) { { 'name' => name } }

        it 'updates the app name' do
          app_update.update(app_model, message)
          app_model.reload

          expect(app_model.name).to eq(name)
        end

        it 'creates an audit event' do
          app_update.update(app_model, message)

          event = Event.last
          expect(event.type).to eq('audit.app.update')
          expect(event.actor).to eq('1337')
          expect(event.actor_name).to eq(user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
          expect(event.actee_name).to eq(name)
          expect(event.metadata['updated_fields']).to include('name')
        end
      end

      context 'when updating the environment variables' do
        let(:environment_variables) { { 'VARIABLE' => 'VALUE' } }
        let(:message) { { 'environment_variables' => environment_variables } }

        it 'updates the app name' do
          app_update.update(app_model, message)
          app_model.reload

          expect(app_model.environment_variables).to eq(environment_variables)
        end

        it 'creates an audit event' do
          app_update.update(app_model, message)

          event = Event.last
          expect(event.type).to eq('audit.app.update')
          expect(event.actor).to eq('1337')
          expect(event.actor_name).to eq(user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
          expect(event.metadata['updated_fields']).to include('environment_variables')
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
