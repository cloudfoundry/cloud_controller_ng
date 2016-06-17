require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DownloadDropletsController do
    let(:timeout_in_seconds) { 120 }
    let(:cc_addr) { '1.2.3.4' }
    let(:cc_port) { 5678 }
    let(:staging_user) { 'user' }
    let(:staging_password) { 'password' }

    let(:workspace) { Dir.mktmpdir }
    let(:original_staging_config) do
      {
        external_host: cc_addr,
        external_port: cc_port,
        staging: {
          auth: {
            user: staging_user,
            password: staging_password
          }
        },
        nginx: { use_nginx: true },
        resource_pool: {
          resource_directory_key: 'cc-resources',
          fog_connection: {
            provider: 'Local',
            local_root: Dir.mktmpdir('resourse_pool', workspace)
          }
        },
        packages: {
          fog_connection: {
            provider: 'Local',
            local_root: Dir.mktmpdir('packages', workspace)
          },
          app_package_directory_key: 'cc-packages',
        },
        droplets: {
          droplet_directory_key: 'cc-droplets',
          fog_connection: {
            provider: 'Local',
            local_root: Dir.mktmpdir('droplets', workspace)
          }
        },
        directories: {
          tmpdir: Dir.mktmpdir('tmpdir', workspace)
        },
        index: 99,
        name: 'api_z1'
      }
    end
    let(:staging_config) { original_staging_config }
    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    let(:app_obj) { AppFactory.make }

    before do
      Fog.unmock!
      TestConfig.override(staging_config)
    end

    after { FileUtils.rm_rf(workspace) }

    describe 'GET /internal/v2/droplets/:guid/:droplet_hash/download' do
      before do
        TestConfig.override(staging_config)
      end

      def upload_droplet
        droplet_file = Tempfile.new(app_obj.guid)
        droplet_file.write('droplet contents')
        droplet_file.close

        droplet = CloudController::DropletUploader.new(app_obj, blobstore)
        droplet.upload(droplet_file.path)
      end

      context 'when using with nginx' do
        before { TestConfig.override(staging_config) }

        it 'succeeds for valid droplets' do
          upload_droplet

          get "/internal/v2/droplets/#{app_obj.guid}/#{app_obj.droplet_hash}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{app_obj.guid}")
        end
      end

      context 'when not using with nginx' do
        before { TestConfig.override(staging_config.merge(nginx: { use_nginx: false })) }

        it 'should return the droplet' do
          upload_droplet

          get "/internal/v2/droplets/#{app_obj.guid}/#{app_obj.droplet_hash}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('droplet contents')
        end
      end

      context 'with a valid app but no droplet' do
        it 'raises an error' do
          get "/internal/v2/droplets/#{app_obj.guid}/#{app_obj.droplet_hash}/download"
          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to eq("Staging error: droplet not found for #{app_obj.guid}")
        end

        it 'fails if blobstore is remote' do
          allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(false)
          get "/internal/v2/droplets/#{app_obj.guid}/#{app_obj.droplet_hash}/download"
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an invalid droplet_hash' do
        it 'returns an error' do
          get "/internal/v2/droplets/#{app_obj.guid}/bogus/download"
          expect(last_response.status).to eq(404)
        end
      end

      context 'with an invalid app' do
        it 'should return an error' do
          get '/internal/v2/droplets/bad/bogus/download'
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the blobstore is not local' do
        before do
          allow_any_instance_of(CloudController::Blobstore::FogClient).to receive(:local?).and_return(false)
        end

        it 'should redirect to the url provided by the blobstore_url_generator' do
          allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).and_return('http://example.com/somewhere/else')
          get "/internal/v2/droplets/#{app_obj.guid}/#{app_obj.droplet_hash}/download"
          expect(last_response).to be_redirect
          expect(last_response.header['Location']).to eq('http://example.com/somewhere/else')
        end
      end

      context 'when the app is a v3 app' do
        let(:v3_app) { AppModel.make(droplet: droplet) }
        let(:process) { App.make(app: v3_app) }
        let(:droplet) { DropletModel.make(state: 'STAGED') }

        def upload_v3_droplet
          droplet_file = Tempfile.new(v3_app.guid)
          droplet_file.write('droplet contents')
          droplet_file.close

          VCAP::CloudController::Jobs::V3::DropletUpload.new(droplet_file.path, droplet.guid).perform
          process.droplet_hash = droplet.reload.droplet_hash
          process.save
        end

        it 'succeeds for valid droplets' do
          upload_v3_droplet

          get "/internal/v2/droplets/#{process.guid}/#{process.droplet_hash}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{process.droplet_hash}")
        end

        context 'when the blobstore is not local' do
          before do
            allow_any_instance_of(CloudController::Blobstore::FogClient).to receive(:local?).and_return(false)
          end

          it 'should redirect to the url provided by the blobstore_url_generator' do
            upload_v3_droplet
            allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_droplet_download_url).and_return('http://example.com/somewhere/else')

            get "/internal/v2/droplets/#{process.guid}/#{process.droplet_hash}/download"

            expect(last_response).to be_redirect
            expect(last_response.header['Location']).to eq('http://example.com/somewhere/else')
          end
        end
      end
    end
  end
end
