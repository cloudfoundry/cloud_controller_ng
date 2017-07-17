require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppCrashedController do
    describe 'POST /internal/apps/:process_guid/crashed' do
      let(:diego_process) { AppFactory.make(state: 'STARTED', diego: true) }
      let(:process_guid) { Diego::ProcessGuid.from(diego_process.guid, 'some-version-guid') }
      let(:url) { "/internal/apps/#{process_guid}/crashed" }

      let(:crashed_request) do
        {
          'instance'         => Sham.guid,
          'index'            => 3,
          'exit_status'      => 137,
          'exit_description' => 'description',
          'reason'           => 'CRASHED'
        }
      end

      before do
        @internal_user     = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      describe 'authentication' do
        context 'when missing authentication' do
          it 'fails with authentication required' do
            header('Authorization', nil)
            post url, crashed_request
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using invalid credentials' do
          it 'fails with authenticatiom required' do
            authorize 'bar', 'foo'
            post url, crashed_request
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using valid credentials' do
          it 'succeeds' do
            post url, MultiJson.dump(crashed_request)
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match /MessageParseError/
          end
        end
      end

      context 'with a diego process' do
        it 'audits the app crashed event' do
          post url, MultiJson.dump(crashed_request)
          expect(last_response.status).to eq(200)

          app_event = Event.find(actee: diego_process.guid, actor_type: 'app')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('app.crash')
          expect(app_event.actor_type).to eq('app')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
          expect(app_event.metadata['index']).to eq(crashed_request['index'])
          expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
          expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
          expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
        end

        it 'audits the process crashed event' do
          post url, MultiJson.dump(crashed_request)
          expect(last_response.status).to eq(200)

          app_event = Event.find(actee: diego_process.guid, actor_type: 'process')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('audit.app.process.crash')
          expect(app_event.actor_type).to eq('process')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.actee_type).to eq('app')
          expect(app_event.actee).to eq(diego_process.app.guid)
          expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
          expect(app_event.metadata['index']).to eq(crashed_request['index'])
          expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
          expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
          expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
        end
      end

      context 'with a dea app' do
        let(:dea_process) { AppFactory.make(state: 'STARTED', diego: false) }
        let(:process_guid) { Diego::ProcessGuid.from(dea_process.guid, 'some-version-guid') }
        let(:url) { "/internal/apps/#{process_guid}/crashed" }

        it 'fails with a 403' do
          post url, MultiJson.dump(crashed_request)

          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /CF-UnableToPerform/
        end
      end

      context 'when the app does no longer exist' do
        before { diego_process.delete }

        it 'fails with a 404' do
          post url, MultiJson.dump(crashed_request)

          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'POST /internal/v4/apps/:process_guid/crashed' do
      let(:diego_process) { AppFactory.make(state: 'STARTED', diego: true) }
      let(:process_guid) { Diego::ProcessGuid.from(diego_process.guid, 'some-version-guid') }
      let(:url) { "/internal/v4/apps/#{process_guid}/crashed" }

      let(:crashed_request) do
        {
          'instance'         => Sham.guid,
          'index'            => 3,
          'exit_status'      => 137,
          'exit_description' => 'description',
          'reason'           => 'CRASHED'
        }
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match /MessageParseError/
          end
        end
      end

      context 'with a diego process' do
        it 'audits the app crashed event' do
          post url, MultiJson.dump(crashed_request)
          expect(last_response.status).to eq(200)

          app_event = Event.find(actee: diego_process.guid, actor_type: 'app')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('app.crash')
          expect(app_event.actor_type).to eq('app')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
          expect(app_event.metadata['index']).to eq(crashed_request['index'])
          expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
          expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
          expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
        end

        it 'audits the process crashed event' do
          post url, MultiJson.dump(crashed_request)
          expect(last_response.status).to eq(200)

          app_event = Event.find(actee: diego_process.guid, actor_type: 'process')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('audit.app.process.crash')
          expect(app_event.actor_type).to eq('process')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.actee_type).to eq('app')
          expect(app_event.actee).to eq(diego_process.app.guid)
          expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
          expect(app_event.metadata['index']).to eq(crashed_request['index'])
          expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
          expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
          expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
        end
      end

      context 'with a dea app' do
        let(:dea_process) { AppFactory.make(state: 'STARTED', diego: false) }
        let(:process_guid) { Diego::ProcessGuid.from(dea_process.guid, 'some-version-guid') }

        it 'fails with a 403' do
          post url, MultiJson.dump(crashed_request)

          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /CF-UnableToPerform/
        end
      end

      context 'when the app does no longer exist' do
        before { diego_process.delete }

        it 'fails with a 404' do
          post url, MultiJson.dump(crashed_request)

          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
