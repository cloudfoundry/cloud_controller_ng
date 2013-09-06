require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CustomBuildpacksController, type: :controller do
    describe "/v2/custom_buildpacks" do
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

      context "POST - create a custom buildpack" do
        after { reset_database }
        
        it "returns NOT AUTHORIZED (403) for non admins" do
          post "/v2/custom_buildpacks", req_body, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        it "returns a CREATED (201) if an admin uploads a build pack" do
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
          expect(last_response.status).to eq(201)
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
          response = Yajl::Parser.parse(last_response.body)
          entity = response['entity']
          expect(entity['name']).to eq('dynamic_test_buildpack')
          expect(entity['key']).to eq('dynamic_test_buildpack.tar.gz')
        end
        
        it 'fails when duplicate name is used' do
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
          post "/v2/custom_buildpacks", req_body, headers_for(admin)
          expect(last_response.status).to eq(400)
        end
      end

      context "GET" do
        before(:all) { @test_buildpack = VCAP::CloudController::Models::Buildpack.create_from_hash({name: "test_buildpack", key: "xyz"})}
        describe "/v2/custom_buildpacks/:name" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/custom_buildpacks/#{@test_buildpack[:guid]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            entity = decoded_response['entity']
            metadata = decoded_response['metadata']
            expect(metadata['guid']).to eq(@test_buildpack[:guid])
            expect(entity['name']).to eq(@test_buildpack[:name])
            expect(entity['key']).to eq(@test_buildpack[:key])
          end
        end

        describe "/v2/custom_buildpacks?name" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/custom_buildpacks?name=#{@test_buildpack[:name]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(1)
            resource = decoded_response['resources'][0]
            entity = resource['entity']
            metadata = resource['metadata']
            expect(metadata['guid']).to eq(@test_buildpack[:guid])
            expect(entity['name']).to eq(@test_buildpack[:name])
            expect(entity['key']).to eq(@test_buildpack[:key])
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
            expect(decoded_response['total_results']).to eq(1)
            expect(decoded_response["resources"][0]["entity"]).to eq({"name" => "test_buildpack", "key"=>"xyz"})
          end
        end
      end
      
      context 'UPDATE' do
        describe '/v2/custom_buildpacks/:guid' do
          it 'returns NOT_IMPLEMENTED (501)' do
            put "/v2/custom_buildpacks/abcdef", {}, headers_for(admin)
            expect(last_response.status).to eq(501)
          end
        end
        
        describe '/v2/custom_buildpacks/:guid/bits' do
          it "returns NOT AUTHORIZED (403) for non admins"
          it "returns a CREATED (201) if an admin uploads a build pack"
          it "updates the file in the blobstore"
        end
      end
      
      context 'DELETE' do
        it 'returns NOT FOUND (404) if the buildpack does not exist' do
          delete "/v2/custom_buildpacks/abcd", req_body, headers_for(admin)
          expect(last_response.status).to eq(404)
        end
        
        context 'create a default buildpack' do
          around(:each) do |test|
            @test_buildpack = VCAP::CloudController::Models::Buildpack[name: "test_buildpack"]
            @test_buildpack.destroy if @test_buildpack            
            @test_buildpack = VCAP::CloudController::Models::Buildpack.create_from_hash({name: "test_buildpack", key: "xyz"})

            test.run

            @test_buildpack.destroy if @test_buildpack.exists?
          end
          
          it "returns NOT AUTHORIZED (403) for non admins" do
            delete "/v2/custom_buildpacks/#{@test_buildpack[:guid]}", req_body, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a NO CONTENT (204) if an admin deletes a build pack" do
            @file.should_receive(:destroy)
            delete "/v2/custom_buildpacks/#{@test_buildpack[:guid]}", req_body, headers_for(admin)            
            expect(last_response.status).to eq(204)
          end

          it "destroys the buildpack key in the blobstore" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.stub(:files).and_return(double(:files, :head => @file, create: {}))
            @file.should_receive(:destroy)

            delete "/v2/custom_buildpacks/#{@test_buildpack[:guid]}", req_body, headers_for(admin)
            expect(Models::Buildpack.find(name: "dynamic_test_buildpack")).to be_nil
          end
        end
      end
    end
  end
end
