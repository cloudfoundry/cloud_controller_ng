require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CustomBuildpacksController, type: :controller do
    describe "POST /v2/custom_buildpacks" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:admin){ VCAP::CloudController::Models::User.make(:admin => true, :active => true) }
      let(:user) { VCAP::CloudController::Models::User.make(:admin => false, :active => true) }

      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, "file.zip")
        create_zip(zip_name, 1)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_tar_gz) do
        tar_gz_name = File.join(tmpdir, "file.tar.gz")
        create_zip(tar_gz_name, 1)
        tar_gz_name = File.new(tar_gz_name)
        Rack::Test::UploadedFile.new(tar_gz_name)
      end

        let(:req_body) {{
          :name => "dynamic_test_buildpack",
          :custom_buildpacks => valid_zip,
      }}

      before do
        @file = double(:file, {
            :public_url => "https://some-bucket.example.com/ab/cd/abcdefg",
            :key => "123-456",
        })
        buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
        buildpack_blobstore.stub(:files).and_return(double(:files, :head => @file, create: {}))
      end

      describe "POST /v2/custom_buildpacks" do
        after { reset_database }
        it "returns 401 for non admins" do
          post "/v2/custom_buildpacks", req_body, headers_for(user)
          expect(last_response.status).to eq(401)
        end

        it "returns a 200 if an admin uploads a build pack" do
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
          expect(last_response.status).to eq(200)
        end

        it "takes a buildpack file and adds it to the custom buildpacks blobstore with the correct key" do
          CloudController::DependencyLocator.instance.upload_handler.stub(:uploaded_file).and_return(valid_zip)
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack_blobstore.files.should_receive(:create).with({
                                                                     :key => "dynamic_test_buildpack.zip",
                                                                     :body => anything,
                                                                     :public => true
                                                                 })

          post "/v2/custom_buildpacks", req_body, headers_for(admin)
          expect(Models::Buildpack.find(name: "dynamic_test_buildpack").key).to eq("dynamic_test_buildpack.zip")
        end

        it "gets the uploaded file from the upload handler" do
          upload_handler = CloudController::DependencyLocator.instance.upload_handler
          upload_handler.should_receive(:uploaded_file)
            .with(hash_including("name" => "dynamic_test_buildpack"),"custom_buildpacks")
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
        end

        it "uses the correct file extension on the key" do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack_blobstore.files.should_receive(:create).with({
                                                                     :key => "dynamic_test_buildpack.tar.gz",
                                                                     :body => anything,
                                                                     :public => true
                                                                 })

          req_body[:custom_buildpacks] = valid_tar_gz
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
        end
      end

      context "GET" do
        before(:all) { VCAP::CloudController::Models::Buildpack.create_from_hash({name: "test_buildpack", key: "xyz"})}
        describe "/v2/custom_buildpacks/:name" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/custom_buildpacks/test_buildpack", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response).to eq({"success"=>true, "model"=>"{\"name\":\"test_buildpack\",\"key\":\"xyz\"}"})
          end
        end

        describe "/v2/custom_buildpacks/:name/bits" do
          it "lets you retrieve the bits for a specific buildpack" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.files.should_receive(:head).with('xyz').and_return(@file)

            get "/v2/custom_buildpacks/test_buildpack/bits", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(last_response.headers).to include({"X-Accel-Redirect" => @file.public_url})
          end
        end

        describe "/v2/custom_buildpacks" do
          it "lets you retrieve a list of available buildpacks" do
            get "/v2/custom_buildpacks", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response["resources"][0]["entity"]).to eq({"name" => "test_buildpack", "key"=>"xyz"})
          end
        end
      end
    end
  end
end
