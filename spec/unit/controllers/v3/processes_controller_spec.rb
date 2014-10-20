require "spec_helper"

module VCAP::CloudController
  describe ProcessesController do
    describe "GET /v3/processes/:guid" do
      it "404s when the process does not exist" do
        user = VCAP::CloudController::User.make
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
  end
end
