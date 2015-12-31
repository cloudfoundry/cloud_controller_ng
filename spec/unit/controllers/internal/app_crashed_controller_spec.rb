require 'spec_helper'

module VCAP::CloudController
  describe AppCrashedController do
    let(:diego_app) do
      AppFactory.make.tap do |app|
        app.package_state = 'PENDING'
        app.state = 'STARTED'
        app.staging_task_id = 'task-1'
        app.diego = true
        app.save
      end
    end

    let(:process_guid) { Diego::ProcessGuid.from(diego_app.guid, 'some-version-guid') }

    let(:url) { "/internal/apps/#{process_guid}/crashed" }

    let(:crashed_request) do
      {
        'instance' => Sham.guid,
        'index' => 3,
        'exit_status' => 137,
        'exit_description' => 'description',
        'reason' => 'CRASHED'
      }
    end

    before do
      @internal_user = 'internal_user'
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

    context 'with a diego app' do
      it 'audits the app crashed event' do
        post url, MultiJson.dump(crashed_request)
        expect(last_response.status).to eq(200)

        app_event = Event.find(actee: diego_app.guid)

        expect(app_event).to be
        expect(app_event.space).to eq(diego_app.space)
        expect(app_event.type).to eq('app.crash')
        expect(app_event.actor_type).to eq('app')
        expect(app_event.actor).to eq(diego_app.guid)
        expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
        expect(app_event.metadata['index']).to eq(crashed_request['index'])
        expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
        expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
        expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
      end
    end

    context 'with a dea app' do
      let(:dea_app) do
        AppFactory.make.tap do |app|
          app.package_state = 'PENDING'
          app.state = 'STARTED'
          app.staging_task_id = 'task-1'
          app.save
        end
      end

      let(:process_guid) { Diego::ProcessGuid.from(dea_app.guid, 'some-version-guid') }

      let(:url) { "/internal/apps/#{process_guid}/crashed" }

      it 'fails with a 403' do
        post url, MultiJson.dump(crashed_request)

        expect(last_response.status).to eq(400)
        expect(last_response.body).to match /CF-UnableToPerform/
      end
    end

    context 'when the app does no longer exist' do
      before { diego_app.delete }

      it 'fails with a 404' do
        post url, MultiJson.dump(crashed_request)

        expect(last_response.status).to eq(404)
      end
    end

    context 'with a v3 app' do
      let(:v3_app) { AppModel.make(space_guid: diego_app.space.guid) }

      before do
        diego_app.app_guid = v3_app.guid
        diego_app.save
      end

      it 'audits the app crashed event' do
        post url, MultiJson.dump(crashed_request)
        expect(last_response.status).to eq(200)

        app_event = Event.find(actee: v3_app.guid)

        expect(app_event).to be
        expect(app_event.space).to eq(diego_app.space)
        expect(app_event.type).to eq('app.crash')
        expect(app_event.actor_type).to eq('app')
        expect(app_event.actor).to eq(v3_app.guid)
        expect(app_event.metadata['instance']).to eq(crashed_request['instance'])
        expect(app_event.metadata['index']).to eq(crashed_request['index'])
        expect(app_event.metadata['exit_status']).to eq(crashed_request['exit_status'])
        expect(app_event.metadata['exit_description']).to eq(crashed_request['exit_description'])
        expect(app_event.metadata['reason']).to eq(crashed_request['reason'])
      end
    end
  end
end
