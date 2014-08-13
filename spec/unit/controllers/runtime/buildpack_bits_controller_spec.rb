require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BuildpackBitsController do
    let(:user) { make_user }
    let(:tmpdir) { Dir.mktmpdir }
    let(:filename) { "file.zip" }
    let(:sha_valid_zip) do
      File.new(valid_zip.path).hexdigest
    end
    let(:sha_valid_zip2) { File.new(valid_zip2.path).hexdigest }
    let(:sha_valid_tar_gz) { File.new(valid_tar_gz.path).hexdigest }

    let(:valid_zip) do
      zip_name = File.join(tmpdir, filename)
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_zip2) do
      zip_name = File.join(tmpdir, filename)
      TestZip.create(zip_name, 3, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    let(:valid_tar_gz) do
      tar_gz_name = File.join(tmpdir, "file.tar.gz")
      TestZip.create(tar_gz_name, 1, 1024)
      tar_gz_name = File.new(tar_gz_name)
      Rack::Test::UploadedFile.new(tar_gz_name)
    end

    let(:expected_sha_valid_zip) { "#{@buildpack.guid}_#{sha_valid_zip}" }

    before do
      @file = double(:file, {
                       :public_url => "https://some-bucket.example.com/ab/cd/abcdefg",
                       :key => "123-456",
      })
      buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
      allow(buildpack_blobstore).to receive(:files).and_return(double(:files, :head => @file, create: {}))
    end

    after { FileUtils.rm_rf(tmpdir) }

    context "Buildpack binaries" do
      let (:test_buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: "upload_binary_buildpack", position: 0 }) }

      context "/v2/buildpacks/:guid/bits" do
        before do
          Delayed::Worker.delay_jobs = false
        end

        after { Delayed::Worker.delay_jobs = true }

        let(:upload_body) { { :buildpack => valid_zip, :buildpack_name => valid_zip.path } }

        it "returns NOT AUTHORIZED (403) for non admins" do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        it "returns a CREATED (201) if an admin uploads a zipped build pack" do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body, admin_headers
          expect(last_response.status).to eq(201)
        end

        it "takes a buildpack file and adds it to the custom buildpacks blobstore with the correct key" do
          allow(CloudController::DependencyLocator.instance.upload_handler).to receive(:uploaded_file).and_return(valid_zip)
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expected_key = "#{test_buildpack.guid}_#{sha_valid_zip}"

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body, admin_headers
          buildpack = Buildpack.find(name: 'upload_binary_buildpack')
          expect(buildpack.key).to eq(expected_key)
          expect(buildpack.filename).to eq(filename)
          expect(buildpack_blobstore.exists?(expected_key)).to be true
        end

        it "gets the uploaded file from the upload handler" do
          upload_handler = CloudController::DependencyLocator.instance.upload_handler
          expect(upload_handler).to receive(:uploaded_file).
            with(hash_including('buildpack_name' => filename), "buildpack").
            and_return(valid_zip)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body, admin_headers
        end

        it "requires a filename as part of the upload" do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => "abc" }, admin_headers
          expect(last_response.status).to eql 400
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290002)
          expect(json['description']).to match(/a filename must be specified/)
        end

        it "requires a file to be uploaded" do
          expect(FileUtils).not_to receive(:rm_f)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: nil, buildpack_name: "abc.zip" }, admin_headers
          expect(last_response.status).to eq(400)
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290002)
          expect(json['description']).to match(/a file must be provided/)
        end

        it "does not allow non-zip files" do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expect(buildpack_blobstore).not_to receive(:cp_to_blobstore)

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_tar_gz }, admin_headers
          expect(last_response.status).to eql 400
          json = MultiJson.load(last_response.body)
          expect(json['code']).to eq(290002)
          expect(json['description']).to match(/only zip files allowed/)
        end

        it "removes the old buildpack binary when a new one is uploaded" do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip2 }, admin_headers

          expected_sha = "#{test_buildpack.guid}_#{sha_valid_zip2}"
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          expect(buildpack_blobstore.exists?(expected_sha)).to be true

          put "/v2/buildpacks/#{test_buildpack.guid}/bits", upload_body, admin_headers
          response = MultiJson.load(last_response.body)
          entity = response['entity']
          expect(entity['name']).to eq('upload_binary_buildpack')
          expect(entity['filename']).to eq(filename)
          expect(buildpack_blobstore.exists?(expected_sha)).to be false
        end

        it 'reports a no content if the same buildpack is uploaded again' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip }, admin_headers
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip }, admin_headers

          expect(last_response.status).to eq(204)
        end

        it 'allowed when same bits but different filename are uploaded again' do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip }, admin_headers
          new_name = File.join(File.dirname(valid_zip.path), "newfilename.zip")
          File.rename(valid_zip.path, new_name)
          newfile = Rack::Test::UploadedFile.new(File.new(new_name))
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => newfile }, admin_headers

          expect(last_response.status).to eq(201)
        end

        it "removes the uploaded buildpack file" do
          expect(FileUtils).to receive(:rm_f).with(/.*ngx.upload.*/)
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip }, admin_headers
        end

        it "does not allow upload if the buildpack is locked" do
          locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: "locked_buildpack", locked: true, position: 0 })
          put "/v2/buildpacks/#{locked_buildpack.guid}/bits", { :buildpack => valid_zip2 }, admin_headers
          expect(last_response.status).to eq(409)
        end

        it "does allow upload if the buildpack has been unlocked" do
          locked_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: "locked_buildpack", locked: true, position: 0 })
          put "/v2/buildpacks/#{locked_buildpack.guid}", '{"locked": false}', admin_headers

          put "/v2/buildpacks/#{locked_buildpack.guid}/bits", { :buildpack => valid_zip2 }, admin_headers
          expect(last_response.status).to eq(201)
        end

        context "when the upload file is nil" do
          it "should be a bad request" do
            expect(FileUtils).not_to receive(:rm_f)
            put "/v2/buildpacks/#{test_buildpack.guid}/bits", { buildpack: nil }, admin_headers
            expect(last_response.status).to eq(400)
          end
        end

        context "when the same bits are uploaded twice" do
          let (:test_buildpack2) { VCAP::CloudController::Buildpack.create_from_hash({ name: "buildpack2", position: 0 }) }
          before do
            put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip2 }, admin_headers
            put "/v2/buildpacks/#{test_buildpack2.guid}/bits", { :buildpack => valid_zip2 }, admin_headers
          end

          it "should have different keys" do
            bp1 = Buildpack.find(name: 'upload_binary_buildpack')
            bp2 = Buildpack.find(name: 'buildpack2')
            expect(bp1.key).to_not eq(bp2.key)
          end
        end

      end

      context "/v2/buildpacks/:guid/download" do
        let(:staging_user) { "user" }
        let(:staging_password) { "password" }
        before do
          TestConfig.override({
            :staging => {
              :timeout_in_seconds => 240,
              :auth => {
                :user => staging_user,
                :password => staging_password
              }
            },
        })
        end

        before { test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({ name: "get_binary_buildpack", key: 'xyz', position: 0 }) }

        it "returns NOT AUTHORIZED (403) users without correct basic auth" do
          get "/v2/buildpacks/#{test_buildpack.guid}/download", '{}'
          expect(last_response.status).to eq(403)
        end

        it "lets users with correct basic auth retrieve the bits for a specific buildpack" do
          put "/v2/buildpacks/#{test_buildpack.guid}/bits", { :buildpack => valid_zip }, admin_headers
          authorize(staging_user, staging_password)
          get "/v2/buildpacks/#{test_buildpack.guid}/download"
          expect(last_response.status).to eq(302)
          expect(last_response.header['Location']).to match(/cc-buildpacks/)
        end
      end
    end
  end
end
