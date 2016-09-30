require 'spec_helper'
require 'membrane'

module VCAP::CloudController
  module Dea
    RSpec.describe StagingCompletionController do
      let(:buildpack) { Buildpack.make }
      let(:buildpack_key) { buildpack.key }
      let(:detected_buildpack) { 'detected_buildpack' }
      let(:droplet_sha1) { 'gobbledygook' }
      let(:start_command) { '/usr/bin/letsparty' }
      let(:procfile) { '/path/to/procfile' }
      let(:staging_error) { nil }
      let(:dea_id) { 'dea_id' }

      let(:staging_response) do
        {
          'task_id' => task_id,
          'detected_buildpack' => detected_buildpack,
          'buildpack_key' => buildpack_key,
          'droplet_sha1' => droplet_sha1,
          'detected_start_command' => start_command,
          'procfile' => procfile,
          'error' => staging_error,
          'dea_id' => dea_id,
        }
      end

      let(:v2_app) { AppFactory.make(state: 'STOPPED') }
      let(:droplet) { DropletModel.make(app: v2_app.app, package: v2_app.latest_package, state: DropletModel::STAGING_STATE) }

      let(:staging_guid) { v2_app.guid }
      let(:task_id) { droplet.guid }
      let(:url) { "/internal/dea/staging/#{staging_guid}/completed" }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      describe 'authentication' do
        context 'when missing authentication' do
          it 'fails with authentication required' do
            header('Authorization', nil)
            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using invalid credentials' do
          it 'fails with authenticatiom required' do
            authorize 'bar', 'foo'
            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(401)
          end
        end

        context 'when using valid credentials' do
          before do
            allow_any_instance_of(Dea::Stager).to receive(:staging_complete)
          end

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
      end

      context 'with a valid app' do
        it 'calls the stager with the droplet and response' do
          expect_any_instance_of(Dea::Stager).to receive(:staging_complete).with(droplet, staging_response)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'returns a 200 when the response includes an error from the DEA' do
          expect_any_instance_of(Dea::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('StagerError'))

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'raises a ServerError for non-api errors from staging_response' do
          expect_any_instance_of(Dea::Stager).to receive(:staging_complete).and_raise('something')

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(500)
          expect(last_response.body).to match /ServerError/
        end
      end

      context 'when the process does not exist' do
        before { v2_app.delete }

        it 'fails with a 404' do
          post url, MultiJson.dump(staging_response)

          expect(last_response.status).to eq(404)
        end
      end

      context 'when the task_id does not match the app' do
        let(:task_id) { 'bogus_task_id' }

        it 'discards the response and fails with a 400' do
          expect_any_instance_of(Dea::Stager).to_not receive(:staging_complete)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /InvalidRequest/
        end

        context 'because the droplet no longer exists' do
          before { DropletModel.dataset.destroy }

          it 'discards the response and fails with a 400' do
            expect_any_instance_of(Dea::Stager).to_not receive(:staging_complete)

            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(400)
            expect(last_response.body).to match /InvalidRequest/
          end
        end
      end
    end
  end
end
