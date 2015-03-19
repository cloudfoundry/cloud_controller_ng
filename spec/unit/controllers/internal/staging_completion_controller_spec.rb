require 'spec_helper'
require 'membrane'
require 'cloud_controller/diego/staging_guid'

module VCAP::CloudController
  describe StagingCompletionController do
    let(:stager) { instance_double(Diego::Stager, staging_complete: nil) }

    let(:buildpack) { Buildpack.make }

    def make_diego_app
      AppFactory.make.tap do |app|
        app.package_state = 'PENDING'
        app.state = 'STARTED'
        app.staging_task_id = Sham.guid
        app.diego = true
        app.save
      end
    end

    def make_dea_app
      AppFactory.make.tap do |app|
        app.package_state = 'PENDING'
        app.state = 'STARTED'
        app.staging_task_id = Sham.guid
        app.save
      end
    end

    let(:staged_app) { make_diego_app }

    let(:app_id) { staged_app.guid }
    let(:task_id) { staged_app.staging_task_id }
    let(:staging_guid) { Diego::StagingGuid.from_app(staged_app) }
    let(:buildpack_key) { buildpack.key }
    let(:detected_buildpack) { 'detected_buildpack' }
    let(:execution_metadata) { 'execution_metadata' }

    let(:url) { "/internal/staging/#{staging_guid}/completed" }

    let(:staging_response) do
      {
        buildpack_key: buildpack_key,
        detected_buildpack: detected_buildpack,
        execution_metadata: execution_metadata
      }
    end

    before do
      @internal_user = 'internal_user'
      @internal_password = 'internal_password'
      authorize @internal_user, @internal_password

      allow_any_instance_of(Stagers).to receive(:stager_for_app).and_return(stager)
    end

    describe 'authentication' do
      context 'when missing authentication' do
        it 'fails with authentication required' do
          header('Authorization', nil)
          post url, staging_response
          expect(last_response.status).to eq(401)
        end
      end

      context 'when using invalid credentials' do
        it 'fails with authenticatiom required' do
          authorize 'bar', 'foo'
          post url, staging_response
          expect(last_response.status).to eq(401)
        end
      end

      context 'when using valid credentials' do
        it 'succeeds' do
          post url, MultiJson.dump(staging_response)
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

      context 'with an invalid staging guid' do
        let(:task_id) { 'bogus-taskid' }

        it 'fails with a 400' do
          post url, MultiJson.dump(staging_response)
        end
      end
    end

    context 'with a diego app' do
      it 'calls the stager with the staging guid and response' do
        expect(stager).to receive(:staging_complete).with(staging_guid, staging_response)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200)
      end

      it 'propagates api errors from staging_response' do
        expect(stager).to receive(:staging_complete).and_raise(Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match /JobTimeout/
      end
    end

    context 'with a dea app' do
      let(:staged_app) { make_dea_app }

      it 'fails with a 403' do
        post url, MultiJson.dump(staging_response)

        expect(last_response.status).to eq(403)
        expect(last_response.body).to match /StagingBackendInvalid/
      end
    end

    context 'when the app does no longer exist' do
      before { staged_app.delete }

      it 'fails with a 404' do
        post url, MultiJson.dump(staging_response)

        expect(last_response.status).to eq(404)
      end
    end
  end
end
