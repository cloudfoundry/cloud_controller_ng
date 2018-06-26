require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppCrashedController do
    describe 'POST /internal/v4/apps/:process_guid/crashed' do
      let(:diego_process) { ProcessModelFactory.make(state: 'STARTED', diego: true) }
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
