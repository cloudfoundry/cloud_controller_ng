require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe AppReschedulingController do
    describe 'POST /internal/v4/apps/:process_guid/rescheduling' do
      let(:diego_process) { ProcessModelFactory.make(state: 'STARTED', diego: true) }
      let(:process_guid) { Diego::ProcessGuid.from(diego_process.guid, 'some-version-guid') }
      let(:url) { "/internal/v4/apps/#{process_guid}/rescheduling" }

      let(:rescheduling_request) do
        {
          'instance' => Sham.guid,
          'index'    => 3,
          'cell_id'  => Sham.guid,
          'reason'   => 'Helpful reason for rescheduling',
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

      it 'audits the process rescheduling event' do
        post url, MultiJson.dump(rescheduling_request)
        expect(last_response.status).to eq(200)

        app_event = Event.find(actee: diego_process.guid, actor_type: 'process')

        expect(app_event).to be
        expect(app_event.space).to eq(diego_process.space)
        expect(app_event.type).to eq('audit.app.process.rescheduling')
        expect(app_event.actor_type).to eq('process')
        expect(app_event.actor).to eq(diego_process.guid)
        expect(app_event.actee_type).to eq('app')
        expect(app_event.actee).to eq(diego_process.app.guid)
        expect(app_event.metadata['instance']).to eq(rescheduling_request['instance'])
        expect(app_event.metadata['index']).to eq(rescheduling_request['index'])
        expect(app_event.metadata['cell_id']).to eq(rescheduling_request['cell_id'])
        expect(app_event.metadata['reason']).to eq(rescheduling_request['reason'])
      end

      context 'when the app does no longer exist' do
        before { diego_process.delete }

        it 'fails with a 404' do
          post url, MultiJson.dump(rescheduling_request)

          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
