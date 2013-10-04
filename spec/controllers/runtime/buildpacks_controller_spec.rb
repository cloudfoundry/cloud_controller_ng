require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BuildpacksController, type: :controller do
    describe "/v2/buildpacks" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:user) { make_user }
      let(:filename) { "file.zip" }

      after { FileUtils.rm_rf(tmpdir) }

      let(:valid_zip) do
        zip_name = File.join(tmpdir, filename)
        create_zip(zip_name, 1)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:sha_valid_zip) { sha1 = Digest::SHA1.file(valid_zip.path).hexdigest }

      let(:valid_zip2) do
        zip_name = File.join(tmpdir, filename)
        create_zip(zip_name, 3)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:sha_valid_zip2) { sha1 = Digest::SHA1.file(valid_zip2.path).hexdigest }

      let(:valid_tar_gz) do
        tar_gz_name = File.join(tmpdir, "file.tar.gz")
        create_zip(tar_gz_name, 1)
        tar_gz_name = File.new(tar_gz_name)
        Rack::Test::UploadedFile.new(tar_gz_name)
      end

      let(:sha_valid_tar_gz) { sha1 = Digest::SHA1.file(valid_tar_gz.path).hexdigest }

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
          post "/v2/buildpacks", req_body, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        it "returns a CREATED (201) if an admin uploads a build pack" do
          post "/v2/buildpacks", req_body, admin_headers
          expect(last_response.status).to eq(201)
          entity = decoded_response(symbolize_keys: true)[:entity]
          expect(entity[:name]).to eq('dynamic_test_buildpack')
        end

        it 'creates a buildpack with a default priority' do
          post "/v2/buildpacks", req_body, admin_headers
          expect(decoded_response['entity']['priority']).to eq(0)
        end

        it 'sets the priority if provided' do
          post "/v2/buildpacks", Yajl::Encoder.encode({name: "dynamic_test_buildpack", priority: 10}), admin_headers
          expect(decoded_response['entity']['priority']).to eq(10)
        end

        it 'fails when duplicate name is used' do
          post "/v2/buildpacks", req_body, admin_headers
          post "/v2/buildpacks", req_body, admin_headers
          expect(last_response.status).to eq(400)
        end

        it 'fails when the name has non alphanumeric characters' do
          ["git://github.com", "$abc", "foobar!"].each do |name|
            post "/v2/buildpacks", Yajl::Encoder.encode({name: name}), admin_headers
            expect(last_response.status).to eq(400)
          end
        end

        it "allows aphanumerics, dashes and underscores in the buildpack name" do
          ["abc", "a-b", "a_b", "ab123"].each do |name|
            post "/v2/buildpacks", Yajl::Encoder.encode({name: name}), admin_headers
            expect(last_response.status).to eq(201)
          end
        end
      end

      context "GET" do
        before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "get_buildpack", key: "xyz", priority: 0}) }
        after(:all) { @test_buildpack.destroy }

        describe "/v2/buildpacks/:guid" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/buildpacks/#{@test_buildpack[:guid]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            entity = decoded_response['entity']
            metadata = decoded_response['metadata']
            expect(metadata['guid']).to eq(@test_buildpack[:guid])
            expect(entity['name']).to eq(@test_buildpack[:name])
          end
        end

        describe "/v2/buildpacks?name" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/buildpacks?name=#{@test_buildpack[:name]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(1)
            resource = decoded_response['resources'][0]
            entity = resource['entity']
            metadata = resource['metadata']
            expect(metadata['guid']).to eq(@test_buildpack[:guid])
            expect(entity['name']).to eq(@test_buildpack[:name])
          end
        end

        describe "/v2/buildpacks" do
          it "lets you retrieve a list of available buildpacks" do
            get "/v2/buildpacks", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response["total_results"]).to eq(1)
            expect(decoded_response["resources"][0]["entity"]).to eq({'name' => 'get_buildpack', 'priority' => 0})
          end
        end
      end

      context 'UPDATE' do
        before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "update_buildpack", key: "xyz", priority: 0}) }
        after(:all) { @test_buildpack.destroy }

        it "returns NOT AUTHORIZED (403) for non admins" do
          put "/v2/buildpacks/#{@test_buildpack.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        describe '/v2/buildpacks/:guid' do
          it 'updates the priority' do
            put "/v2/buildpacks/#{@test_buildpack.guid}", '{"priority": 10}', admin_headers
            expect(last_response.status).to eq(201)
            expect(decoded_response['entity']['priority']).to eq(10)
          end
        end
      end

      context 'Buildpack binaries' do
        context "/v2/buildpacks/:guid/bits" do
          before(:each) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "upload_binary_buildpack", priority: 0}) }
          after(:each) { @test_buildpack.destroy }
          let(:upload_body) { {:buildpack => valid_zip} }

          it "returns NOT AUTHORIZED (403) for non admins" do
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", upload_body, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a CREATED (201) if an admin uploads a zipped build pack" do
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
            expect(last_response.status).to eq(201)
          end

          it "takes a buildpack file and adds it to the custom buildpacks blobstore with the correct key" do
            CloudController::DependencyLocator.instance.upload_handler.stub(:uploaded_file).and_return(valid_zip)
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore

            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
            expect(Buildpack.find(name: 'upload_binary_buildpack').key).to eq(sha_valid_zip)
            expect(buildpack_blobstore.exists?(sha_valid_zip)).to be_true
          end

          it "gets the uploaded file from the upload handler" do
            upload_handler = CloudController::DependencyLocator.instance.upload_handler
            upload_handler.should_receive(:uploaded_file).
              with(hash_including('buildpack_name'=> filename), "buildpack").
              and_return(valid_zip)
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
          end

          it "does not allow non-zip files" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.should_not_receive(:cp_to_blobstore)

            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_tar_gz}, admin_headers
            expect(last_response.status).to eql 400
            json = Yajl::Parser.parse(last_response.body)
            expect(json['code']).to eq(290002)
            expect(json['description']).to match(/only zip files allowed/)
          end

          it "removes the old buildpack binary when a new one is uploaded" do
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_zip2}, admin_headers

            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            expect(buildpack_blobstore.exists?(sha_valid_zip2)).to be_true

            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", upload_body, admin_headers
            response = Yajl::Parser.parse(last_response.body)
            entity = response['entity']
            expect(entity['name']).to eq('upload_binary_buildpack')
            expect(buildpack_blobstore.exists?(sha_valid_zip2)).to be_false
          end

          it 'reports a conflict if the same buildpack is uploaded again' do
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_zip}, admin_headers
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_zip}, admin_headers

            expect(last_response.status).to eq(409)
          end

          it "removes the uploaded buildpack file" do
            FileUtils.should_receive(:rm_f).with(filename)
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_zip}, admin_headers
          end

          context "when the upload file is nil" do
            it "should be okay" do
              FileUtils.should_not_receive(:rm_f)
              expect {
                post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {buildpack: nil}, admin_headers
              }.to raise_error
            end
          end
        end

        context "/v2/buildpacks/:guid/download" do
          let(:staging_user) { "user" }
          let(:staging_password) { "password" }
          before do
            config_override(
              {
                :staging => {
                  :auth => {
                    :user => staging_user,
                    :password => staging_password
                  }
                },
              })
          end

          before(:all) { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash({name: "get_binary_buildpack", key: 'xyz', priority: 0}) }
          after(:all) { @test_buildpack.destroy }

          it "returns NOT AUTHORIZED (403) users without correct basic auth" do
            get "/v2/buildpacks/#{@test_buildpack.guid}/download", {}
            expect(last_response.status).to eq(403)
          end

          it "lets users with correct basic auth retrieve the bits for a specific buildpack" do
            post "/v2/buildpacks/#{@test_buildpack.guid}/bits", {:buildpack => valid_zip}, admin_headers
            authorize(staging_user, staging_password)
            get "/v2/buildpacks/#{@test_buildpack.guid}/download"
            expect(last_response.status).to eq(302)
            expect(last_response.header['Location']).to match(/cc-buildpacks/)
          end
        end
      end

      context 'DELETE' do
        it 'returns NOT FOUND (404) if the buildpack does not exist' do
          delete "/v2/buildpacks/abcd", {}, admin_headers
          expect(last_response.status).to eq(404)
        end

        context 'create a default buildpack' do
          after { @test_buildpack.destroy if @test_buildpack.exists? }

          it "returns NOT AUTHORIZED (403) for non admins" do
            @test_buildpack = VCAP::CloudController::Buildpack.make
            delete "/v2/buildpacks/#{@test_buildpack.guid}", {}, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a NO CONTENT (204) if an admin deletes a build pack" do
            @test_buildpack = VCAP::CloudController::Buildpack.make
            delete "/v2/buildpacks/#{@test_buildpack.guid}", {}, admin_headers
            expect(last_response.status).to eq(204)
          end

          it "destroys the buildpack key in the blobstore" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            @test_buildpack = VCAP::CloudController::Buildpack.make

            delete "/v2/buildpacks/#{@test_buildpack.guid}", {}, admin_headers
            expect(Buildpack.find(name: @test_buildpack.name)).to be_nil
            expect(buildpack_blobstore.files).to have(0).items
          end

          it "does not fail if no buildpack bits were ever uploaded" do
            @test_buildpack = VCAP::CloudController::Buildpack.make(key: nil)
            delete "/v2/buildpacks/#{@test_buildpack.guid}", {}, admin_headers
            expect(last_response.status).to eql(204)
            expect(Buildpack.find(name: @test_buildpack.name)).to be_nil
          end
        end
      end
    end
  end
end