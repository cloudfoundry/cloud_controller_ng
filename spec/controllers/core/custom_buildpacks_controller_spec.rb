require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CustomBuildpacksController, type: :controller do
    describe "POST /v2/custom_buildpacks" do
      let(:tmpdir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, "file.zip")
        create_zip(zip_name, 1)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:req_body) {{
          :name => "test_buildpack",
          :custom_buildpacks => valid_zip,
      }}

      before do
        file = double(:file, {
            :public_url => "https://some-bucket.example.com/ab/cd/abcdefg",
            :key => "123-456",
        })
        VCAP::CloudController::BlobStore.any_instance.stub(:files).and_return(double(:files, :head => file, create: {}))
      end

      it "returns 403 for non admins" do
        user = VCAP::CloudController::Models::User.make(:admin => false, :active => true)
        post "/v2/custom_buildpacks", req_body, headers_for(user)
        expect(last_response.status).to eq(401)
      end

      it "returns a 200 if an admin uploads a build pack" do
        admin = VCAP::CloudController::Models::User.make(:admin => true, :active => true)
        post "/v2/custom_buildpacks", req_body, headers_for(admin)
        expect(last_response.status).to eq(200)
      end

      it "takes a buildpack file and adds it to the custom buildpacks blobstore"
    end
  end
end
