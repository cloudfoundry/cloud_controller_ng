require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::BuildpackBitsController do
    let(:user) { make_user }
    let(:filename) { 'file.zip' }
    let(:sha_valid_zip) { Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_file(valid_zip) }
    let(:sha_valid_zip2) { Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_file(valid_zip2) }
    let(:sha_valid_tar_gz) { Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_file(valid_tar_gz) }

    let(:valid_zip_manifest_tmpdir) { Dir.mktmpdir }
    let(:valid_zip_manifest) do
      zip_name = File.join(valid_zip_manifest_tmpdir, filename)
      TestZip.create(zip_name, 1, 1024) do |zipfile|
        zipfile.get_output_stream('manifest.yml') do |f|
          f.write("---\nstack: stack-from-manifest\n")
        end
      end
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip_unknown_stack_tmpdir) { Dir.mktmpdir }
    let(:valid_zip_unknown_stack) do
      zip_name = File.join(valid_zip_unknown_stack_tmpdir, filename)
      TestZip.create(zip_name, 1, 1024) do |zipfile|
        zipfile.get_output_stream('manifest.yml') do |f|
          f.write("---\nstack: unknown-stack\n")
        end
      end
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip_tmpdir) { Dir.mktmpdir }
    let!(:valid_zip) do
      zip_name = File.join(valid_zip_tmpdir, filename)
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip_copy_tmpdir) { Dir.mktmpdir }
    let!(:valid_zip_copy) do
      zip_name = File.join(valid_zip_copy_tmpdir, filename)
      FileUtils.cp(valid_zip.path, zip_name)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip2_tmpdir) { Dir.mktmpdir }
    let!(:valid_zip2) do
      zip_name = File.join(valid_zip2_tmpdir, filename)
      TestZip.create(zip_name, 3, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_tar_gz_tmpdir) { Dir.mktmpdir }
    let(:valid_tar_gz) do
      tar_gz_name = File.join(valid_tar_gz_tmpdir, 'file.tar.gz')
      TestZip.create(tar_gz_name, 1, 1024)
      tar_gz_name = File.new(tar_gz_name)
      Rack::Test::UploadedFile.new(tar_gz_name)
    end

    before do
      set_current_user_as_admin
    end

    after do
      FileUtils.rm_rf(valid_zip_manifest_tmpdir)
      FileUtils.rm_rf(valid_zip_unknown_stack_tmpdir)
      FileUtils.rm_rf(valid_zip_tmpdir)
      FileUtils.rm_rf(valid_zip_copy_tmpdir)
      FileUtils.rm_rf(valid_zip2_tmpdir)
      FileUtils.rm_rf(valid_tar_gz_tmpdir)
    end

    context 'Buildpack binaries' do
      let(:test_buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: nil, position: 0 }) }

      before { CloudController::DependencyLocator.instance.register(:upload_handler, UploadHandler.new(TestConfig.config_instance)) }

      context 'PUT /v2/buildpacks/:guid/bits' do
        before do
          TestConfig.override(directories: { tmpdir: File.dirname(valid_zip.path) })
          @cache = Delayed::Worker.delay_jobs
          Delayed::Worker.delay_jobs = false

          Stack.create(name: 'stack')
          Stack.create(name: 'stack-from-manifest')
        end

        after { Delayed::Worker.delay_jobs = @cache }

        let(:upload_body) { { buildpack: valid_zip, buildpack_name: valid_zip.path } }

        it 'returns FORBIDDEN (403) for non admins' do
          set_current_user(user)

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body
          expect(last_response.status).to eq(403)
        end

        it 'returns a CREATED (201) if an admin uploads a zipped build pack' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body
          expect(last_response.status).to eq(201)
        end

        it 'takes a buildpack file and adds it to the custom buildpacks blobstore with the correct key' do
          test_buildpack.update(stack: 'stack')

          allow(CloudController::DependencyLocator.instance.upload_handler).to receive(:uploaded_file).and_return(valid_zip.path)
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expected_key = "#{test_buildpack.guid}_#{sha_valid_zip}"

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body
          expect(last_response.status).to eq(201)

          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.key).to eq(expected_key)
          expect(buildpack.filename).to eq(filename)
          expect(buildpack.stack).to eq('stack')
          expect(buildpack_blobstore.exists?(expected_key)).to be true
        end

        it 'gets the uploaded file from the upload handler' do
          upload_handler = CloudController::DependencyLocator.instance.upload_handler
          expect(upload_handler).to receive(:uploaded_file).with(hash_including('buildpack_name' => filename), 'buildpack').and_return(valid_zip)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body
        end

        it 'sets the buildpack stack if it is unset and in buildpack manifest' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip_manifest, buildpack_name: valid_zip_manifest.path }
          expect(last_response.status).to be 201

          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.stack).to eq('stack-from-manifest')
        end

        it 'returns ERROR (422) if provided stack does not exist' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip_unknown_stack, buildpack_name: valid_zip_unknown_stack.path }
          expect(last_response.status).to be 422

          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.stack).to be_nil
        end

        it 'sets the buildpack stack to nil if it is unset and NOT in buildpack manifest' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip, buildpack_name: valid_zip.path }
          expect(last_response.status).to be 201

          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.stack).to be_nil
        end

        it 'requires an existing stack to be the same as one in the manifest if it exists' do
          Stack.make(name: 'not-from-manifest')
          test_buildpack.update(stack: 'not-from-manifest')

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip_manifest, buildpack_name: valid_zip_manifest.path }
          expect(last_response.status).to be 422

          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(390_011)
          expect(json['description']).to eql 'Uploaded buildpack stack (stack-from-manifest) does not match not-from-manifest'

          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.stack).to eq('not-from-manifest')
        end

        it 'requires a filename as part of the upload' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: 'abc' }
          expect(last_response.status).to be 400
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290_002)
          expect(json['description']).to match(/a filename must be specified/)
        end

        it 'requires a file to be uploaded' do
          expect(FileUtils).not_to receive(:rm_f)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: nil, buildpack_name: 'abc.zip' }
          expect(last_response.status).to eq(400)
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290_002)
          expect(json['description']).to match(/a file must be provided/)
        end

        it 'does not allow non-zip files' do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expect(buildpack_blobstore).not_to receive(:cp_to_blobstore)

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_tar_gz }
          expect(last_response.status).to be 400
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290_002)
          expect(json['description']).to match(/only zip files allowed/)
        end

        it 'removes the old buildpack binary when a new one is uploaded' do
          test_buildpack.update(stack: 'stack')

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip2 }

          expected_sha = "#{test_buildpack.guid}_#{sha_valid_zip2}"
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expect(buildpack_blobstore.exists?(expected_sha)).to be true

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body
          response = MultiJson.load(last_response.body)
          expect(response['entity']['name']).to eq('upload_binary_buildpack')
          expect(response['entity']['filename']).to eq(filename)
          expect(buildpack_blobstore.exists?(expected_sha)).to be false
        end

        it 'reports a no content if the same buildpack is uploaded again' do
          # We noticed strange interactions between Rack::Test::UploadedFile and our
          # FakeNginxReverseProxy after upgrading Rack::Test. Seems like the original
          # valid_zip gets corrupted the second time around, so we're uploading a "copy" of it instead here.
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip }
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip_copy }

          expect(last_response.status).to eq(204), "status: #{last_response.status}, body: #{last_response.body}"
        end

        it 'does not allow uploading a buildpack which will update the stack that already has a buildpack with the same name' do
          first_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: 'nice_buildpack', stack: nil, position: 0 })
          put "/v2/buildpacks/#{first_buildpack.guid}/bits", { buildpack: valid_zip_manifest }

          expect(Buildpack.find(name: 'nice_buildpack').stack).to eq('stack-from-manifest')

          new_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: first_buildpack.name, stack: nil, position: 0 })
          put "/v2/buildpacks/#{new_buildpack.guid}/bits", { buildpack: valid_zip_manifest }

          expect(last_response.status).to eq(422)
        end

        it 'allowed when same bits but different filename are uploaded again' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip }
          new_name = File.join(File.dirname(valid_zip.path), 'newfilename.zip')
          File.rename(valid_zip.path, new_name)
          newfile = Rack::Test::UploadedFile.new(File.new(new_name))
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: newfile }

          expect(last_response.status).to eq(201)
        end

        it 'removes the uploaded buildpack file' do
          expect(FileUtils).to receive(:rm_f).with(/.*ngx.upload.*/)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip }
        end

        it 'does not allow upload if the buildpack is locked' do
          locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: 'locked_buildpack', stack: 'stack', locked: true, position: 0 })
          put "/v2/buildpacks/#{locked_buildpack.guid}/bits", { buildpack: valid_zip2 }
          expect(last_response.status).to eq(409)
        end

        it 'does allow upload if the buildpack has been unlocked' do
          locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: 'locked_buildpack', stack: 'stack', locked: true, position: 0 })
          put "/v2/buildpacks/#{locked_buildpack.guid}", '{"locked": false}'

          put "/v2/buildpacks/#{locked_buildpack.guid}/bits", { buildpack: valid_zip2 }
          expect(last_response.status).to eq(201)
        end

        context 'when the upload file is nil' do
          it 'is a bad request' do
            expect(FileUtils).not_to receive(:rm_f)
            put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: nil }
            expect(last_response.status).to eq(400)
          end
        end

        context 'when the same bits are uploaded twice' do
          let(:test_buildpack2) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'buildpack2', stack: 'stack', position: 0 }) }

          before do
            put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip2 }
            put "/v2/buildpacks/#{test_buildpack2.guid}/bits", { buildpack: valid_zip2 }
          end

          it 'has different keys' do
            bp1 = Buildpack.find(name: 'upload_binary_buildpack')
            bp2 = Buildpack.find(name: 'buildpack2')
            expect(bp1.key).not_to eq(bp2.key)
          end
        end
      end

      context 'GET /v2/buildpacks/:guid/download' do
        let(:staging_user) { 'user' }
        let(:staging_password) { 'pass[%3a]word' }
        let(:staging_config) do
          {
            staging: { timeout_in_seconds: 240, auth: { user: staging_user, password: staging_password } },
            directories: { tmpdir: File.dirname(valid_zip.path) }
          }
        end

        before do
          TestConfig.override(**staging_config)
          VCAP::CloudController::Buildpack.create_from_hash({ name: 'get_binary_buildpack', stack: nil, key: 'xyz', position: 0 })
        end

        it 'returns NOT AUTHENTICATED (401) users without correct basic auth' do
          get "/v2/buildpacks/#{test_buildpack.guid}/download", '{}'
          expect(last_response.status).to eq(401)
        end

        it 'lets users with correct basic auth retrieve the bits for a specific buildpack' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: valid_zip }
          authorize(staging_user, staging_password)
          get "/v2/buildpacks/#{test_buildpack.guid}/download"
          expect(last_response.status).to eq(302)
          expect(last_response.header['Location']).to match(/cc-buildpacks/)
        end

        it 'returns 404 for missing bits' do
          authorize(staging_user, staging_password)
          get "/v2/buildpacks/#{test_buildpack.guid}/download"
          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
