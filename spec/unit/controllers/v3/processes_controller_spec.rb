require "spec_helper"

module VCAP::CloudController
  describe ProcessesController do
    describe "GET /v3/processes/:guid" do
      it "404s when the process does not exist" do
        user = User.make
        get "/v3/processes/non-existing", {}, headers_for(user)
        expect(last_response.status).to eq(404)
      end

      context "permissions" do
        it "returns a 404 for an unauthorized user" do
          user = User.make
          process = ProcessModel.make
          get "/v3/processes/#{process.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe "POST /v3/processes" do
      it "returns a 422 when the params are invalid" do
        invalid_opts = {
          "space_guid" => Space.make.guid,
        }
        post "/v3/processes", invalid_opts.to_json, admin_headers
        expect(last_response.status).to eq(422)
      end

      context "permissions" do
        it "returns a 404 for an unauthorized user" do
          user = User.make
          valid_opts = {
            "name" => "my-process",
            "memory" => 256,
            "instances" => 2,
            "disk_quota" => 1024,
            "space_guid" => Space.make.guid,
            "stack_guid" => Stack.make.guid
          }
          post "/v3/processes", valid_opts.to_json, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe "DELETE /v3/processes/:guid" do
      it "returns a 404 when the process does not exist" do
        delete "/v3/processes/bogus-guid", {}, admin_headers
        expect(last_response.status).to eq(404)
      end

      context "permissions" do
        it "returns a 404 for an unauthorized user" do
          user = User.make
          process = ProcessFactory.make
          delete "/v3/processes/#{process.guid}", {}, headers_for(user)
          expect(last_response.status).to eq(404)
        end
      end
    end
  end
end
