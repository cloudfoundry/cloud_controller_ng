require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DownloadDropletsController do
    describe 'GET /internal/v2/droplets/:guid/:droplet_hash/download' do
      let(:workspace) { Dir.mktmpdir }
      let(:original_staging_config) do
        {
          packages: {
            fog_connection:            {
              provider:   'Local',
              local_root: Dir.mktmpdir('packages', workspace)
            },
            app_package_directory_key: 'cc-packages',
          },
          droplets: {
            droplet_directory_key: 'cc-droplets',
            fog_connection:        {
              provider:   'Local',
              local_root: Dir.mktmpdir('droplets', workspace)
            }
          },
        }
      end
      let(:staging_config) { original_staging_config }
      let(:blobstore) do
        CloudController::DependencyLocator.instance.droplet_blobstore
      end

      let(:v3_app) { AppModel.make(droplet: droplet) }
      let(:process) { ProcessModel.make(app: v3_app) }
      let(:droplet) { DropletModel.make(state: 'STAGED') }

      before do
        Fog.unmock!
        TestConfig.override(staging_config)
      end
      after { FileUtils.rm_rf(workspace) }

      def get_and_redirect(url)
        get url
        expect(last_response.status).to eq(302)
        get last_response.headers['Location']
      end

      def upload_droplet
        droplet_file = Tempfile.new(v3_app.guid)
        droplet_file.write('droplet contents')
        droplet_file.close

        Jobs::V3::DropletUpload.new(droplet_file.path, droplet.guid, skip_state_transition: false).perform
      end

      describe 'blobstore_url_generator' do
        let(:hostname) { Config.config.get(:internal_service_hostname) }
        let(:tls_port) { Config.config.get(:tls_port) }
        let(:expected_redirect) { "https://#{hostname}:#{tls_port}/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download" }

        it 'should redirect to the url provided by the blobstore_url_generator' do
          upload_droplet
          get "/internal/v2/droplets/#{process.guid}/#{process.droplet_checksum}/download"

          expect(last_response).to be_redirect
          expect(last_response.header['Location']).to eq(expected_redirect)
        end
      end

      context 'when using with nginx' do
        it 'succeeds for valid droplets' do
          upload_droplet

          get_and_redirect "/internal/v2/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{process.droplet_hash}")
        end
      end

      context 'when not using with nginx' do
        let(:staging_config) { original_staging_config.merge(nginx: { use_nginx: false }) }

        it 'succeeds for valid droplets' do
          upload_droplet

          get_and_redirect "/internal/v2/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('droplet contents')
        end
      end

      context 'with a valid app but no droplet in the blobstore' do
        before do
          droplet.update(droplet_hash: 'not-in-blobstore')
        end

        it 'raises an error' do
          get_and_redirect "/internal/v2/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to eq("Staging error: droplet not found for #{process.guid}")
        end

        it 'fails if blobstore is remote' do
          get_and_redirect "/internal/v2/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an invalid droplet_hash' do
        it 'returns an error' do
          get_and_redirect "/internal/v2/droplets/#{process.guid}/bogus/download"
          expect(last_response.status).to eq(404)
        end
      end

      context 'with an invalid app' do
        it 'should return an error' do
          get_and_redirect '/internal/v2/droplets/bad/bogus/download'
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'GET /internal/v4/droplets/:guid/:droplet_hash/download' do
      let(:workspace) { Dir.mktmpdir }
      let(:original_staging_config) do
        {
          packages: {
            fog_connection:            {
              provider:   'Local',
              local_root: Dir.mktmpdir('packages', workspace)
            },
            app_package_directory_key: 'cc-packages',
          },
          droplets: {
            droplet_directory_key: 'cc-droplets',
            fog_connection:        {
              provider:   'Local',
              local_root: Dir.mktmpdir('droplets', workspace)
            }
          },
        }
      end
      let(:staging_config) { original_staging_config }
      let(:blobstore) do
        CloudController::DependencyLocator.instance.droplet_blobstore
      end

      let(:v3_app) { AppModel.make(droplet: droplet) }
      let(:process) { ProcessModel.make(app: v3_app) }
      let(:droplet) { DropletModel.make(state: 'STAGED') }

      before do
        Fog.unmock!
        TestConfig.override(staging_config)
      end
      after { FileUtils.rm_rf(workspace) }

      def upload_droplet(target_droplet=droplet)
        droplet_file = Tempfile.new(v3_app.guid)
        droplet_file.write('droplet contents')
        droplet_file.close

        Jobs::V3::DropletUpload.new(droplet_file.path, target_droplet.guid, skip_state_transition: false).perform
      end

      context 'when using with a revision' do
        let(:new_droplet) { DropletModel.make(state: 'STAGED') }

        it 'succeeds when the the revisions droplet doesnt match the processes "desired" droplet' do
          upload_droplet
          upload_droplet(new_droplet)
          new_droplet.reload

          v3_app.update(revisions_enabled: true)
          revision = RevisionModel.make(app: v3_app, droplet: new_droplet)
          process.update(revision: revision)

          get "/internal/v4/droplets/#{process.guid}/#{new_droplet.checksum}/download"
          expect(last_response.status).to eq(200), last_response.body
          expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{new_droplet.droplet_hash}")
        end
      end

      context 'when using with nginx' do
        it 'succeeds for valid droplets' do
          upload_droplet

          get "/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{process.droplet_hash}")
        end
      end

      context 'when not using with nginx' do
        let(:staging_config) { original_staging_config.merge(nginx: { use_nginx: false }) }

        it 'succeeds for valid droplets' do
          upload_droplet

          get "/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('droplet contents')
        end
      end

      context 'with a valid app but no droplet in the blobstore' do
        before do
          droplet.update(droplet_hash: 'not-in-blobstore')
        end

        it 'raises an error' do
          get "/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to eq("Staging error: droplet not found for #{process.guid}")
        end

        it 'fails if blobstore is remote' do
          allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(false)
          get "/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download"
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an invalid droplet_hash' do
        it 'returns an error' do
          get "/internal/v4/droplets/#{process.guid}/bogus/download"
          expect(last_response.status).to eq(404)
        end
      end

      context 'with an invalid app' do
        it 'should return an error' do
          get '/internal/v4/droplets/bad/bogus/download'
          expect(last_response.status).to eq(404)
        end
      end

      context 'when the blobstore is not local' do
        before do
          allow_any_instance_of(CloudController::Blobstore::FogClient).to receive(:local?).and_return(false)
        end

        it 'should redirect to the url provided by the blobstore_url_generator' do
          upload_droplet
          allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).and_return('http://example.com/somewhere/else')

          get "/internal/v4/droplets/#{process.guid}/#{process.droplet_checksum}/download"

          expect(last_response).to be_redirect
          expect(last_response.header['Location']).to eq('http://example.com/somewhere/else')
        end

        context 'when using with a revision' do
          let(:new_droplet) { DropletModel.make(state: 'STAGED') }

          it 'succeeds when the the revisions droplet doesnt match the processes "desired" droplet' do
            upload_droplet
            upload_droplet(new_droplet)
            allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).with(droplet).and_return('http://example.com/wrong/droplet')
            allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:droplet_download_url).with(new_droplet).and_return('http://example.com/correct/droplet')

            new_droplet.reload

            v3_app.update(revisions_enabled: true)
            revision = RevisionModel.make(app: v3_app, droplet: new_droplet)
            process.update(revision: revision)

            get "/internal/v4/droplets/#{process.guid}/#{new_droplet.checksum}/download"

            expect(last_response).to be_redirect
            expect(last_response.header['Location']).to eq('http://example.com/correct/droplet')
          end
        end
      end
    end
  end
end
