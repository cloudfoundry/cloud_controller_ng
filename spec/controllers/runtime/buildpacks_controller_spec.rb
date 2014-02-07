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
          expect(decoded_response['entity']['position']).to eq(1)
        end

        it "sets the position correctly even if an invalid position is provided" do
          should_have_been_1 = 10
          post "/v2/buildpacks", Yajl::Encoder.encode({name: "dynamic_test_buildpack", position: should_have_been_1}), admin_headers
          expect(decoded_response['entity']['position']).to eq(1)
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
        let!(:buildpack) do
          should_have_been_1 = 0
          VCAP::CloudController::Buildpack.create_from_hash(name: "get_buildpack", key: "xyz", position: should_have_been_1)
        end

        describe "/v2/buildpacks/:guid" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/buildpacks/#{buildpack[:guid]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            entity = decoded_response['entity']
            metadata = decoded_response['metadata']
            expect(metadata['guid']).to eq(buildpack[:guid])
            expect(entity['name']).to eq(buildpack[:name])
          end
        end

        describe "/v2/buildpacks?name" do
          it "lets you retrieve info for a specific buildpack" do
            get "/v2/buildpacks?name=#{buildpack[:name]}", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(1)
            resource = decoded_response['resources'][0]
            entity = resource['entity']
            metadata = resource['metadata']
            expect(metadata['guid']).to eq(buildpack[:guid])
            expect(entity['name']).to eq(buildpack[:name])
            expect(entity['filename']).to be_nil
          end
        end

        describe "/v2/buildpacks" do
          it "lets you retrieve a list of available buildpacks" do
            get "/v2/buildpacks", {}, headers_for(user)
            expect(last_response.status).to eq(200)
            expect(decoded_response["total_results"]).to eq(1)
            expect(decoded_response["resources"][0]["entity"]).to eq({'name' => 'get_buildpack',
                                                                      'position' => 1,
                                                                      'enabled' => true,
                                                                      'filename' => nil})
          end
        end
      end

      context "UPDATE" do
        let!(:buildpack1) do
          should_have_been_1 = 5
          VCAP::CloudController::Buildpack.create({name: "first_buildpack", key: "xyz", filename: "a", position: should_have_been_1})
        end

        let!(:buildpack2) do
          should_have_been_2 = 10
          VCAP::CloudController::Buildpack.create({name: "second_buildpack", key: "xyz", filename: "b", position: should_have_been_2})
        end

        it "returns NOT AUTHORIZED (403) for non admins" do
          put "/v2/buildpacks/#{buildpack2.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end

        describe "/v2/buildpacks/:guid" do
          it "updates the position" do
            expect {
              put "/v2/buildpacks/#{buildpack2.guid}", '{"position": 1}', admin_headers
              expect(last_response.status).to eq(201)
            }.to change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position, bp.filename] }
            }.from(
                   [["first_buildpack", 1, 'a'], ["second_buildpack", 2, 'b']]
                 ).to(
                   [["second_buildpack", 1, 'b'], ["first_buildpack", 2, 'a']]
                 )
          end

          it "updates current end to beyond end of list" do
            expect {
              put "/v2/buildpacks/#{buildpack2.guid}", '{"position": 15}', admin_headers
              expect(last_response.status).to eq(201)
            }.to_not change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }
          end

          it "updates to position 1 when position < 1" do
            expect {
              put "/v2/buildpacks/#{buildpack2.guid}", '{"position": 0}', admin_headers
              expect(last_response.status).to eq(201)
            }.to change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }.from(
                   [["first_buildpack", 1], ["second_buildpack", 2]]
                 ).to(
                   [["second_buildpack", 1], ["first_buildpack", 2]]
                 )
          end
        end
      end

      context "DELETE" do
        let!(:buildpack1) do
          should_have_been_1 = 5
          VCAP::CloudController::Buildpack.create({name: "first_buildpack", key: "xyz", position: should_have_been_1})
        end

        it "returns NOT FOUND (404) if the buildpack does not exist" do
          delete "/v2/buildpacks/abcd", {}, admin_headers
          expect(last_response.status).to eq(404)
        end

        context "create a default buildpack" do
          it "returns NOT AUTHORIZED (403) for non admins" do
            delete "/v2/buildpacks/#{buildpack1.guid}", {}, headers_for(user)
            expect(last_response.status).to eq(403)
          end

          it "returns a NO CONTENT (204) if an admin deletes a build pack" do
            delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers
            expect(last_response.status).to eq(204)
          end

          it "destroys the buildpack key in the blobstore" do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.cp_to_blobstore(Tempfile.new(['FAKE_BUILDPACK', '.zip']), buildpack1.key)

            delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers

            expect(Buildpack.find(name: buildpack1.name)).to be_nil
            expect { Delayed::Worker.new.work_off(1) }.to change {
              buildpack_blobstore.exists?(buildpack1.key)
            }.from(true).to(false)
          end

          it "does not fail if no buildpack bits were ever uploaded" do
            buildpack1.update_from_hash(key: nil)
            expect(buildpack1.key).to be_nil

            delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers
            expect(last_response.status).to eql(204)
            expect(Buildpack.find(name: buildpack1.name)).to be_nil
          end
        end

        context "positions are adjusted" do
          let!(:buildpack2) do
            should_have_been_2 = 10
            VCAP::CloudController::Buildpack.create({name: "second_buildpack", key: "xyz", position: should_have_been_2})
          end

          let!(:buildpack3) do
            should_have_been_3 = 15
            VCAP::CloudController::Buildpack.create({name: "third_buildpack", key: "xyz", position: should_have_been_3})
          end

          it "shifts down" do
            expect {
            delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers
              expect(last_response.status).to eq(204)
            }.to change {
              Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
            }.from(
                   [["first_buildpack", 1], ["second_buildpack", 2], ["third_buildpack", 3]]
                 ).to(
                   [["second_buildpack", 1], ["third_buildpack", 2]]
                 )
          end
        end
      end
    end
  end
end
