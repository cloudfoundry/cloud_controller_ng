require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe AppReadinessChangedController do
    describe 'POST /internal/v4/apps/:process_guid/readiness_changed' do
      let(:diego_process) { ProcessModelFactory.make(state: 'STARTED', diego: true) }
      let(:process_guid) { Diego::ProcessGuid.from(diego_process.guid, 'some-version-guid') }
      let(:url) { "/internal/v4/apps/#{process_guid}/readiness_changed" }
      let(:ready) { true }

      let(:readiness_changed_request) do
        {
          'instance' => Sham.guid,
          'index' => 3,
          'ready' => ready
        }
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/MessageParseError/)
          end
        end
      end

      context 'when the app is ready' do
        it 'audits the app readiness changed event' do
          post url, Oj.dump(readiness_changed_request)
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq '{}'

          app_event = Event.find(actee: diego_process.guid, actor_type: 'process')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('audit.app.process.ready')
          expect(app_event.actor_type).to eq('process')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.metadata['instance']).to eq(readiness_changed_request['instance'])
          expect(app_event.metadata['index']).to eq(readiness_changed_request['index'])
        end
      end

      context 'when the app is not ready' do
        let(:ready) { false }

        it 'audits the app readiness changed event' do
          post url, Oj.dump(readiness_changed_request)
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq '{}'

          app_event = Event.find(actee: diego_process.guid, actor_type: 'process')

          expect(app_event).to be
          expect(app_event.space).to eq(diego_process.space)
          expect(app_event.type).to eq('audit.app.process.not-ready')
          expect(app_event.actor_type).to eq('process')
          expect(app_event.actor).to eq(diego_process.guid)
          expect(app_event.metadata['instance']).to eq(readiness_changed_request['instance'])
          expect(app_event.metadata['index']).to eq(readiness_changed_request['index'])
        end
      end

      context 'when the app no longer exists' do
        before { diego_process.delete }

        it 'fails with a 404' do
          post url, Oj.dump(readiness_changed_request)

          expect(last_response.status).to eq(404)
          expect(last_response.body).to match(/ProcessNotFound/)
        end
      end
    end
  end
end
