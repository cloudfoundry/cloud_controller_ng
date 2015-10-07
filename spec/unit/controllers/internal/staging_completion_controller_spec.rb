require 'spec_helper'
require 'membrane'
require 'cloud_controller/diego/staging_guid'

module VCAP::CloudController
  describe StagingCompletionController do
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

    context 'staging a v2 app' do
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
      let(:url) { "/internal/staging/#{staging_guid}/completed" }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
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
          before do
            allow_any_instance_of(Diego::Runner).to receive(:start)
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

        context 'with an invalid staging guid' do
          let(:task_id) { 'bogus-taskid' }

          before do
            allow_any_instance_of(Diego::Runner).to receive(:start)
          end

          it 'fails with a 400' do
            post url, MultiJson.dump(staging_response)
          end
        end
      end

      context 'with a diego app' do
        it 'calls the stager with the staging guid and response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(staging_guid, staging_response)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'propagates api errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(Errors::ApiError.new_from_details('JobTimeout'))

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

    context 'staging a v3 package' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/droplet_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: staged_app.guid, state: 'PENDING') }
      let(:staging_guid) { droplet.guid }

      before do
        @internal_user = 'internal_user'
        @internal_password = 'internal_password'
        authorize @internal_user, @internal_password
      end

      it 'calls the stager with the droplet and response' do
        expect_any_instance_of(Diego::V3::Stager).to receive(:staging_complete).with(droplet, staging_response)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200)
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::V3::Stager).to receive(:staging_complete).and_raise(Errors::ApiError.new_from_details('JobTimeout'))

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

      context 'when the package does not exist' do
        before do
          droplet.package_guid = 'not-real'
          droplet.save
        end

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match /Package not found/
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
            allow_any_instance_of(Diego::V3::Stager).to receive(:staging_complete)
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

        it 'expires any old droplets' do
          allow_any_instance_of(Diego::V3::Stager).to receive(:staging_complete)
          allow(Config).to receive(:config) { {} }
          expect_any_instance_of(BitsExpiration).to receive(:expire_droplets!)
          post url, MultiJson.dump(staging_response)
        end
      end
    end
  end
end
