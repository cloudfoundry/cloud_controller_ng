require 'spec_helper'
require 'membrane'

module VCAP::CloudController
  RSpec.describe StagingCompletionController do
    let(:buildpack) { Buildpack.make }
    let(:buildpack_key) { buildpack.key }
    let(:detected_buildpack) { 'detected_buildpack' }
    let(:execution_metadata) { 'execution_metadata' }
    let(:staging_response) do
      {
        result: {
          lifecycle_type: 'buildpack',
          lifecycle_metadata: {
            buildpack_key: buildpack_key,
            detected_buildpack: detected_buildpack,
          },
          execution_metadata: execution_metadata,
          process_types: { web: 'start me' }
        }
      }
    end

    context 'staging a package' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/droplet_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: staged_app.guid, state: DropletModel::STAGING_STATE) }
      let(:staging_guid) { droplet.guid }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      it 'calls the stager with the droplet and response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, staging_response, false)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200)
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match /JobTimeout/
      end

      context 'when the droplet does not exist' do
        let(:staging_guid) { 'asdf' }

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match /Droplet not found/
        end
      end

      context 'when the start query param has a true value' do
        it 'requests staging_complete with start' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(droplet, staging_response, true)

          post "#{url}?start=true", MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
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
            allow_any_instance_of(Diego::Stager).to receive(:staging_complete)
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
      end
    end
  end
end
