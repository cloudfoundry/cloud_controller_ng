require 'spec_helper'

module VCAP::CloudController
  RSpec.describe StagingsController do
    let(:timeout_in_seconds) { 120 }
    let(:cc_addr) { '1.2.3.4' }
    let(:cc_port) { 5678 }
    let(:staging_user) { 'user' }
    let(:staging_password) { 'password' }
    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end
    let(:digester) { Digester.new(algorithm: Digest::MD5, type: :base64digest) }

    let(:buildpack_cache_blobstore) do
      CloudController::DependencyLocator.instance.buildpack_cache_blobstore
    end

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

    # explicitly unstaged app
    let(:app_obj) do
      AppFactory.make.tap do |app|
        app.current_droplet.destroy
        app.reload
      end
    end

    before do
      Fog.unmock!
      TestConfig.override(staging_config)
    end

    after { FileUtils.rm_rf(workspace) }

    shared_examples 'staging bad auth' do |verb, path|
      it 'should return 401 for bad credentials' do
        authorize 'hacker', 'sw0rdf1sh'
        send(verb, "/staging/#{path}/#{app_obj.guid}")
        expect(last_response.status).to eq(401)
      end
    end

    describe 'GET /staging/jobs/:guid' do
      let(:job) { Delayed::Job.enqueue double(perform: nil) }
      let(:job_guid) { job.guid }

      context 'when authorized' do
        before do
          authorize staging_user, staging_password
        end

        it 'returns the job' do
          get "/staging/jobs/#{job_guid}"

          expect(last_response.status).to eq(200)
          expect(decoded_response(symbolize_keys: true)).to eq(StagingJobPresenter.new(job).to_hash)
          expect(decoded_response['metadata']['guid']).to eq(job_guid)
        end
      end

      context 'when not authorized' do
        it 'returns a 401 unauthorized' do
          get "/staging/jobs/#{job_guid}"

          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'GET /staging/packages/:guid' do
      let(:package_without_bits) { PackageModel.make }
      let(:package) { PackageModel.make }
      before { authorize(staging_user, staging_password) }

      def create_test_blob
        tmpdir = Dir.mktmpdir
        file = File.new(File.join(tmpdir, 'afile.txt'), 'w')
        file.print('test blob contents')
        file.close
        CloudController::Blobstore::FogBlob.new(file, nil)
      end

      context 'when using with nginx' do
        before do
          TestConfig.override(staging_config)
          blob = create_test_blob
          allow(blob).to receive(:internal_download_url).and_return("/cc-packages/gu/id/#{package.guid}")
          package_blobstore = instance_double(CloudController::Blobstore::Client, blob: blob, local?: true)
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
        end

        it 'succeeds for valid packages' do
          get "/staging/packages/#{package.guid}"
          expect(last_response.status).to eq(200)

          expect(last_response.headers['X-Accel-Redirect']).to eq("/cc-packages/gu/id/#{package.guid}")
        end
      end

      context 'when not using with nginx' do
        before do
          TestConfig.override(staging_config.merge(nginx: { use_nginx: false }))
          package_blobstore = instance_double(CloudController::Blobstore::Client, blob: create_test_blob, local?: true)
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
        end

        it 'succeeds for valid packages' do
          get "/staging/packages/#{package.guid}"
          expect(last_response.status).to eq(200)

          expect(last_response.body).to eq('test blob contents')
        end
      end

      it 'fails if blobstore is not local' do
        allow_any_instance_of(CloudController::Blobstore::FogClient).to receive(:local?).and_return(false)
        get '/staging/packages/some-guid'
        expect(last_response.status).to eq(400)
      end

      it 'returns an error for non-existent packages' do
        get '/staging/packages/bad-guid'
        expect(last_response.status).to eq(404)
      end

      it 'returns an error for an package without bits' do
        get "/staging/packages/#{package_without_bits.guid}"
        expect(last_response.status).to eq(404)
      end

      include_examples 'staging bad auth', :get, 'packages'
    end

    describe 'POST /staging/v3/droplets/:guid/upload' do
      include TempFileCreator

      let(:droplet) { DropletModel.make }
      let(:file_content) { 'droplet content' }

      let(:upload_req) do
        { upload: { droplet: Rack::Test::UploadedFile.new(temp_file_with_content(file_content)) } }
      end

      before do
        TestConfig.override(staging_config)
        authorize staging_user, staging_password
      end

      it 'schedules a job to upload the droplet to the blobstore' do
        expect {
          post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req
        }.to change {
          Delayed::Job.count
        }.by(1)

        job = Delayed::Job.last
        expect(job.handler).to include('VCAP::CloudController::Jobs::V3::DropletUpload')
        expect(job.handler).to include("droplet_guid: #{droplet.guid}")
        expect(job.handler).to include('ngx.uploads')
        expect(job.queue).to eq('cc-api_z1-99')
        expect(job.guid).not_to be_nil
        expect(last_response.status).to eq 200
      end

      it "returns a JSON body with full url and basic auth to query for job's status" do
        post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req

        job = Delayed::Job.last
        config = VCAP::CloudController::Config.config
        user = config[:staging][:auth][:user]
        password = config[:staging][:auth][:password]
        polling_url = "http://#{user}:#{password}@#{config[:external_domain]}/staging/jobs/#{job.guid}"

        expect(decoded_response.fetch('metadata').fetch('url')).to eql(polling_url)
      end

      it 'returns a JSON body with full url containing the correct external_protocol' do
        TestConfig.config[:external_protocol] = 'https'
        post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req
        expect(decoded_response.fetch('metadata').fetch('url')).to start_with('https://')
      end

      context 'when a content-md5 is specified' do
        it 'returns a 400 if the value does not match the md5 of the body' do
          post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req, 'HTTP_CONTENT_MD5' => 'the-wrong-md5'
          expect(last_response.status).to eq(400)
        end

        it 'succeeds if the value matches the md5 of the body' do
          content_md5 = digester.digest(file_content)
          post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req, 'HTTP_CONTENT_MD5' => content_md5
          expect(last_response.status).to eq(200)
        end
      end

      context 'with an invalid app' do
        it 'returns 404' do
          post '/staging/v3/droplets/bad-droplet/upload', upload_req
          expect(last_response.status).to eq(404)
        end

        it 'does not add a job' do
          expect {
            post '/staging/v3/droplets/bad-droplet/upload', upload_req
          }.not_to change {
            Delayed::Job.count
          }
        end

        context 'when the upload path is nil' do
          let(:upload_req) do
            { upload: { droplet: nil } }
          end

          it 'does not add a job' do
            expect {
              post "/staging/v3/droplets/#{droplet.guid}/upload", upload_req
            }.not_to change {
              Delayed::Job.count
            }
          end
        end
      end

      include_examples 'staging bad auth', :post, 'droplets'
    end

    describe 'POST /staging/v3/buildpack_cache/:stack/:app_guid/upload' do
      include TempFileCreator

      let(:file_content) { 'the-file-content' }
      let(:upload_req) do
        { upload: { droplet: Rack::Test::UploadedFile.new(temp_file_with_content(file_content)) } }
      end
      let(:app_model) { AppModel.make }
      let(:stack) { Sham.name }
      before do
        TestConfig.override(staging_config)
        authorize staging_user, staging_password
      end

      context 'with a valid app' do
        it 'returns 200' do
          post "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/upload", upload_req
          expect(last_response.status).to eq(200)
        end

        it 'stores file path in handle.buildpack_cache_upload_path' do
          expect {
            post "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/upload", upload_req
          }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include("#{app_model.guid}/#{stack}")
          expect(job.handler).to include('ngx.uploads')
          expect(job.handler).to include('buildpack_cache_blobstore')
          expect(job.queue).to eq('cc-api_z1-99')
          expect(job.guid).not_to be_nil
          expect(last_response.status).to eq 200
        end

        context 'when a content-md5 is specified' do
          it 'returns a 400 if the value does not match the md5 of the body' do
            post "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/upload", upload_req, 'HTTP_CONTENT_MD5' => 'the-wrong-md5'
            expect(last_response.status).to eq(400)
          end

          it 'succeeds if the value matches the md5 of the body' do
            content_md5 = digester.digest(file_content)
            post "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/upload", upload_req, 'HTTP_CONTENT_MD5' => content_md5
            expect(last_response.status).to eq(200)
          end
        end
      end

      context 'with an invalid package' do
        it 'returns 404' do
          post '/staging/v3/buildpack_cache/bad-app/upload', upload_req
          expect(last_response.status).to eq(404)
        end

        context 'when the upload path is nil' do
          let(:upload_req) do
            { upload: { droplet: nil } }
          end

          it 'does not create an upload job' do
            expect {
              post "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/upload", upload_req
            }.not_to change {
              Delayed::Job.count
            }
          end
        end
      end
    end

    describe 'GET /staging/v3/buildpack_cache/:stack/:app_guid/download' do
      let(:app_model) { AppModel.make }
      let(:buildpack_cache) { Tempfile.new(app_model.guid) }
      let(:stack) { Sham.name }

      before do
        buildpack_cache.write('droplet contents')
        buildpack_cache.close

        authorize staging_user, staging_password
      end

      after { FileUtils.rm(buildpack_cache.path) }

      def make_request(guid=app_model.guid)
        get "/staging/v3/buildpack_cache/#{stack}/#{guid}/download"
      end

      context 'with a valid buildpack cache' do
        context 'when nginx is enabled' do
          it 'redirects nginx to serve staged droplet' do
            buildpack_cache_blobstore.cp_to_blobstore(
              buildpack_cache.path,
              "#{app_model.guid}/#{stack}"
            )

            make_request
            expect(last_response.status).to eq(200)
            expect(last_response.headers['X-Accel-Redirect']).to match("/cc-droplets/.*/#{app_model.guid}/#{stack}")
          end
        end

        context 'when nginx is disabled' do
          let(:staging_config) do
            original_staging_config.merge({ nginx: { use_nginx: false } })
          end

          it 'should return the buildpack cache' do
            buildpack_cache_blobstore.cp_to_blobstore(
              buildpack_cache.path,
              "#{app_model.guid}/#{stack}"
            )

            make_request
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('droplet contents')
          end
        end
      end

      context 'with a valid buildpack cache but no file' do
        it 'should return an error' do
          make_request
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an invalid buildpack cache' do
        it 'should return an error' do
          make_request('bad_guid')
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'GET /staging/v3/droplets/:guid/download' do
      let(:droplet) { DropletModel.make }
      before { authorize(staging_user, staging_password) }

      def upload_droplet
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, 'test.zip')
        TestZip.create(zipname, 10, 1024)
        file_contents = File.read(zipname)
        Jobs::V3::DropletUpload.new(zipname, droplet.guid).perform
        FileUtils.rm_rf(tmpdir)
        file_contents
      end

      context 'when using with nginx' do
        before { TestConfig.override(staging_config) }

        it 'succeeds for valid droplets' do
          upload_droplet

          get "/staging/v3/droplets/#{droplet.guid}/download"
          expect(last_response.status).to eq(200)

          droplet.reload
          expect(last_response.headers['X-Accel-Redirect']).to eq("/cc-droplets/gu/id/#{droplet.blobstore_key}")
        end
      end

      context 'when not using with nginx' do
        before { TestConfig.override(staging_config.merge(nginx: { use_nginx: false })) }

        it 'succeeds for valid droplets' do
          encoded_expected_body = Base64.encode64(upload_droplet)

          get "/staging/v3/droplets/#{droplet.guid}/download"
          expect(last_response.status).to eq(200)

          encoded_actual_body = Base64.encode64(last_response.body)
          expect(encoded_actual_body).to eq(encoded_expected_body)
        end
      end

      it 'fails if blobstore is not local' do
        allow_any_instance_of(CloudController::Blobstore::FogClient).to receive(:local?).and_return(false)
        get '/staging/v3/droplets/some-guid/download'
        expect(last_response.status).to eq(400)
      end

      it 'returns an error for non-existent droplets' do
        get '/staging/v3/droplets/bad-guid/download'
        expect(last_response.status).to eq(404)
      end

      include_examples 'staging bad auth', :get, 'droplets'
    end
  end
end
