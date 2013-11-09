require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BuildpacksController, type: :controller do
    describe "/v2/buildpacks" do
      let(:user) { make_user }
      let(:req_body) { Yajl::Encoder.encode({:name => "dynamic_test_buildpack"}) }

      context "POST - create a custom buildpack" do
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

        it "creates a buildpack with a default position" do
          post "/v2/buildpacks", req_body, admin_headers
          expect(decoded_response['entity']['position']).to eq(0)
        end

        it "sets the position if provided" do
          post "/v2/buildpacks", Yajl::Encoder.encode({name: "dynamic_test_buildpack", position: 10}), admin_headers
          expect(decoded_response['entity']['position']).to eq(10)
        end

        it "fails when duplicate name is used" do
          post "/v2/buildpacks", req_body, admin_headers
          post "/v2/buildpacks", req_body, admin_headers
          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to eq(290001)
        end

        it "fails when the name has non alphanumeric characters" do
          ["git://github.com", "$abc", "foobar!"].each do |name|
            post "/v2/buildpacks", Yajl::Encoder.encode({name: name}), admin_headers
            expect(last_response.status).to eq(400)
            expect(decoded_response['code']).to eq(290003)
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
        before { @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash(name: "get_buildpack", key: "xyz", position: 0) }

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
            expect(decoded_response["resources"][0]["entity"]).to eq({
              'name' => 'get_buildpack', 'position' => 0, 'enabled' => true})
          end
        end
      end

      context "UPDATE" do
        before(:each) do
          @orig_buildpack = VCAP::CloudController::Buildpack.create_from_hash(name: "original_buildpack", key: "xyz", position: 1)
          @test_buildpack = VCAP::CloudController::Buildpack.create_from_hash(name: "update_buildpack", key: "xyz", position: 2)
        end

        it "returns NOT AUTHORIZED (403) for non admins" do
          put "/v2/buildpacks/#{@test_buildpack.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        describe "/v2/buildpacks/:guid" do
          it "updates the position" do
            expect {
              put "/v2/buildpacks/#{@test_buildpack.guid}", '{"position": 1}', admin_headers
              expect(last_response.status).to eq(201)
            }.to change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }.from(
              [["original_buildpack", 1], ["update_buildpack", 2]]
            ).to(
              [["update_buildpack", 1], ["original_buildpack", 2]]
            )
          end

          it "updates current end to beyond end of list" do
            expect {
              put "/v2/buildpacks/#{@test_buildpack.guid}", '{"position": 10}', admin_headers
              expect(last_response.status).to eq(201)
            }.to_not change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }
          end

          it "updates current end position 0" do
            expect {
              put "/v2/buildpacks/#{@test_buildpack.guid}", '{"position": 0}', admin_headers
              expect(last_response.status).to eq(201)
            }.to change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }.from(
              [["original_buildpack", 1], ["update_buildpack", 2]]
            ).to(
              [["update_buildpack", 0], ["original_buildpack", 1]]
            )
          end
        end
      end

      context "DELETE" do
        it "returns NOT FOUND (404) if the buildpack does not exist" do
          delete "/v2/buildpacks/abcd", {}, admin_headers
          expect(last_response.status).to eq(404)
        end

        context "create a default buildpack" do
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