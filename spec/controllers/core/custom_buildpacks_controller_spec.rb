require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CustomBuildpacksController, type: :controller do
    describe "/v2/custom_buildpacks" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:user) { make_user }

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

      let(:req_body) { Yajl::Encoder.encode({:name => "dynamic_test_buildpack"}) }

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
          post "/v2/custom_buildpacks", req_body, admin_headers
          expect(last_response.status).to eq(201)
          entity = decoded_response(symbolize_keys: true)[:entity]
          expect(entity[:name]).to eq('dynamic_test_buildpack')
        end

        it 'creates a buildpack with a default priority' do
          post "/v2/custom_buildpacks", req_body, admin_headers
          expect(decoded_response['entity']['priority']).to eq(0)
        end

        it 'sets the priority if provided' do
          post "/v2/custom_buildpacks", Yajl::Encoder.encode({name: "dynamic_test_buildpack", priority: 10}), admin_headers
          expect(decoded_response['entity']['priority']).to eq(10)
        end

        it 'fails when duplicate name is used' do
          post "/v2/custom_buildpacks", req_body, admin_headers
          post "/v2/custom_buildpacks", req_body, admin_headers
          expect(last_response.status).to eq(400)
        end
      end

      context "GET" do
        before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "get_buildpack", key: "xyz", priority: 0}) }
        after(:all) { @test_buildpack.destroy }

        describe "/v2/custom_buildpacks/:guid" do
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
            expect(entity['key']).to eq('xyz')
          end
        end

        describe "/v2/custom_buildpacks" do
          it "lets you retrieve a list of available buildpacks" do
            get "/v2/custom_buildpacks", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(1)
            expect(decoded_response["resources"][0]["entity"]).to eq({'name' => 'get_buildpack', 'key' => 'xyz', 'priority' => 0})
          end
        end
      end

      context 'UPDATE' do
        before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "update_buildpack", key: "xyz", priority: 0}) }
        after(:all) { @test_buildpack.destroy }

        it "returns NOT AUTHORIZED (403) for non admins" do
          put "/v2/custom_buildpacks/#{@test_buildpack.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        describe '/v2/custom_buildpacks/:guid' do
          it 'updates the priority' do
            put "/v2/custom_buildpacks/#{@test_buildpack.guid}", '{"priority": 10}', admin_headers
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['priority']).to eq(10)
          end
        end
      end

      context 'Buildpack binaries' do
        context '/v2/custom_buildpacks/:guid/bits' do
          before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "upload_binary_buildpack", key: 'xyz', priority: 0}) }
          after(:all) { @test_buildpack.destroy }
          let(:upload_body) { {:buildpack => valid_zip} }

          it "returns NOT AUTHORIZED (403) for non admins" do
            post "/v2/custom_buildpacks/#{@test_buildpack.guid}/bits", upload_body, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a CREATED (201) if an admin uploads a build pack" do
            post "/v2/custom_buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
            expect(last_response.status).to eq(201)
          end

          it "takes a buildpack file and adds it to the custom buildpacks blobstore with the correct key" do
            CloudController::DependencyLocator.instance.upload_handler.stub(:uploaded_file).and_return(valid_zip)
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.files.should_receive(:create).with({
              :key => "upload_binary_buildpack.zip",
              :body => anything,
              :public => true
              })

              post "/v2/custom_buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
              expect(Buildpack.find(name: 'upload_binary_buildpack').key).to eq('upload_binary_buildpack.zip')
          end

          it "gets the uploaded file from the upload handler" do
            upload_handler = CloudController::DependencyLocator.instance.upload_handler
            upload_handler.should_receive(:uploaded_file)
            .with(hash_including('buildpack_name'=> 'file.zip'), "buildpack")
            post "/v2/custom_buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
          end

          it "uses the correct file extension on the key" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.files.should_receive(:create).with({
              :key => "upload_binary_buildpack.tar.gz",
              :body => anything,
              :public => true
              })

              post "/v2/custom_buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_tar_gz}, admin_headers
              response = Yajl::Parser.parse(last_response.body)
              entity = response['entity']
              expect(entity['name']).to eq('upload_binary_buildpack')
              expect(entity['key']).to eq('upload_binary_buildpack.tar.gz')
          end
        end

        context "/v2/custom_buildpacks/:guid/download" do
          before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "get_binary_buildpack", key: 'xyz', priority: 0}) }
          after(:all) { @test_buildpack.destroy }

          it "returns NOT AUTHORIZED (403) for non admins" do
            get "/v2/custom_buildpacks/#{@test_buildpack.guid}/download", {}, headers_for(user)
          end

          it "lets you retrieve the bits for a specific buildpack" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.files.should_receive(:head).with('xyz').and_return(@file)
            @file.should_receive(:path).and_return(__FILE__)

            get "/v2/custom_buildpacks/#{@test_buildpack.guid}/download", {}, admin_headers
            expect(last_response.status).to eq(200)
            expect(last_response.header['Content-Length']).to eq(File.size(__FILE__).to_s)
          end
        end
      end

      context 'DELETE' do
        it 'returns NOT FOUND (404) if the buildpack does not exist' do
          delete "/v2/custom_buildpacks/abcd", {}, admin_headers
          expect(last_response.status).to eq(404)
        end

        context 'create a default buildpack' do
          around(:each) do |test|
            @test_buildpack = VCAP::CloudController::Buildpack[name: "test_buildpack"]
            @test_buildpack.destroy if @test_buildpack
            @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "test_buildpack", key: "xyz", priority: 0})

            test.run

            @test_buildpack.destroy if @test_buildpack.exists?
          end

          it "returns NOT AUTHORIZED (403) for non admins" do
            delete "/v2/custom_buildpacks/#{@test_buildpack.guid}", {}, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a NO CONTENT (204) if an admin deletes a build pack" do
            @file.should_receive(:destroy)
            delete "/v2/custom_buildpacks/#{@test_buildpack.guid}", {}, admin_headers
            expect(last_response.status).to eq(204)
          end

          it "destroys the buildpack key in the blobstore" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.stub(:files).and_return(double(:files, :head => @file, create: {}))
            @file.should_receive(:destroy)

            delete "/v2/custom_buildpacks/#{@test_buildpack.guid}", {}, admin_headers
            expect(Buildpack.find(name: "dynamic_test_buildpack")).to be_nil
          end
        end
      end
    end
  end
end