require 'spec_helper'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  RSpec.describe AppsSSHController do
    let(:diego) { true }
    let(:enable_ssh) { true }
    let(:user) { User.make }
    let(:app_model) { AppFactory.make(diego: diego, enable_ssh: enable_ssh) }
    let(:instance_index) { '2' }
    let(:space) { app_model.space }

    before do
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return true
    end

    describe 'GET /internal/apps/:guid/ssh_access/:index' do
      context 'as a space developer' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
          set_current_user(user)
        end

        it 'returns a 200 and ProcessGuid' do
          get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          expect(last_response.status).to eq(200)
          expected_process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(app_model)
          expect(decoded_response['process_guid']).to eq(expected_process_guid)
        end

        it 'creates an audit event recording this ssh access' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-authorized')
          expect(event.actor).to eq(user.guid)
          expect(event.metadata).to eq({ 'index' => instance_index })
        end

        context 'when the app is not diego app' do
          let(:diego) { false }

          it 'returns a 400' do
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            expect(last_response.status).to eq(400)
          end

          it 'creates an audit event recording this ssh failure' do
            expect {
              get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            }.to change { Event.count }.by(1)
            event = Event.last
            expect(event.type).to eq('audit.app.ssh-unauthorized')
            expect(event.actor).to eq(user.guid)
            expect(event.metadata).to eq({ 'index' => instance_index })
          end
        end

        context 'when the app is does not allow ssh access' do
          let(:enable_ssh) { false }

          it 'returns a 400' do
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            expect(last_response.status).to eq(400)
          end

          it 'creates an audit event recording this ssh failure' do
            expect {
              get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            }.to change { Event.count }.by(1)
            event = Event.last
            expect(event.type).to eq('audit.app.ssh-unauthorized')
            expect(event.actor).to eq(user.guid)
            expect(event.metadata).to eq({ 'index' => instance_index })
          end
        end

        context 'when the app does not exists' do
          context 'and the user has a valid auth token' do
            it 'returns a 404' do
              get '/internal/apps/does-not-exist/ssh_access/32914083940812934'
              expect(last_response.status).to eq(404)
            end
          end

          context 'and the user does not have a valid auth token' do
            let(:user_with_invalid_token) { nil }

            before { set_current_user(user_with_invalid_token) }

            it 'returns a 401' do
              expect {
                get '/internal/apps/non-existant/ssh_access/324342'
                expect(last_response.status).to eq(401)
              }.not_to change { Event.count }
            end
          end
        end

        context 'when the space allow_ssh is set to false' do
          before do
            space.allow_ssh = false
            space.save
          end

          it 'returns a 400' do
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            expect(last_response.status).to eq(400)
          end

          it 'creates an audit event recording this ssh failure' do
            expect {
              get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            }.to change { Event.count }.by(1)
            event = Event.last
            expect(event.type).to eq('audit.app.ssh-unauthorized')
            expect(event.actor).to eq(user.guid)
            expect(event.metadata).to eq({ 'index' => instance_index })
          end
        end

        context 'when the global allow_app_ssh_access is set to false' do
          before do
            allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return false
          end

          it 'returns a 400' do
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            expect(last_response.status).to eq(400)
          end

          it 'creates an audit event recording this ssh failure' do
            expect {
              get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
            }.to change { Event.count }.by(1)
            event = Event.last
            expect(event.type).to eq('audit.app.ssh-unauthorized')
            expect(event.actor).to eq(user.guid)
            expect(event.metadata).to eq({ 'index' => instance_index })
          end
        end
      end

      context 'as an admin user' do
        let(:admin) { User.make }
        before do
          space.organization.add_user(admin)
          set_current_user(admin, { admin: true })
        end

        it 'returns a 200 and ProcessGuid' do
          get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          expect(last_response.status).to eq(200)
          expected_process_guid = VCAP::CloudController::Diego::ProcessGuid.from_process(app_model)
          expect(decoded_response['process_guid']).to eq(expected_process_guid)
        end

        it 'creates an audit event recording this ssh access' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-authorized')
          expect(event.actor).to eq(admin.guid)
          expect(event.metadata).to eq({ 'index' => instance_index })
        end
      end

      context 'as a user who cannot update' do
        let(:auditor) { User.make }

        before do
          set_current_user(auditor)
          space.organization.add_user(auditor)
          space.add_auditor(auditor)
        end

        it 'returns a 403' do
          get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          expect(last_response.status).to eq(403)
        end
      end

      context 'when the user does not have access to the application' do
        let(:other_user) { User.make }

        before { set_current_user(other_user) }

        it 'returns a 403' do
          get "/internal/apps/#{app_model.guid}/ssh_access"
          expect(last_response.status).to eq(403)
        end

        it 'creates an audit event recording this auth failure' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-unauthorized')
          expect(event.actor).to eq(other_user.guid)
          expect(event.metadata).to eq({ 'index' => instance_index })
        end
      end

      context 'when the user does not have a valid auth token' do
        let(:user_with_invalid_token) { nil }

        before { set_current_user(user_with_invalid_token) }

        it 'returns a 401' do
          get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          expect(last_response.status).to eq(401)
        end

        it 'creates an audit event recording this auth failure' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access/#{instance_index}"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-unauthorized')
          expect(event.metadata).to eq({ 'index' => instance_index })
        end
      end
    end

    describe 'GET /internal/apps/:guid/ssh_access' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
        set_current_user(user)
      end

      context 'when the user can access the app' do
        it 'creates an audit event recording this ssh access with an unknown index' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-authorized')
          expect(event.actor).to eq(user.guid)
          expect(event.metadata).to eq({ 'index' => 'unknown' })
        end
      end

      context 'when the user cannot access the app' do
        let(:enable_ssh) { false }

        it 'creates an audit event recording this ssh failure with an unknown index' do
          expect {
            get "/internal/apps/#{app_model.guid}/ssh_access"
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.ssh-unauthorized')
          expect(event.actor).to eq(user.guid)
          expect(event.metadata).to eq({ 'index' => 'unknown' })
        end
      end
    end
  end
end
