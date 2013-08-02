require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BuildpacksController, type: :controller do
    describe "POST /buildpacks" do

      context "as a basic user" do
        it "returns 403" do
          @user = Models::User.make(admin: false)

          post("/buildpacks", "{}", json_headers(headers_for(@user)))

          expect(last_response.status).to eq(403)
        end
      end

      context "as an admin" do
        before do
          @admin = Models::User.make(admin: true)
          @request_body = Yajl::Encoder.encode("name" => "My Buildpack", "url" => "http://example.com/repo.git")
          @headers = json_headers(headers_for(@admin))
        end

        it "posts a message to nats" do
          DeaClient.should_receive(:add_buildpack).with("My Buildpack", "http://example.com/repo.git")

          post("/buildpacks", @request_body, @headers)
        end

        it "returns 201" do
          DeaClient.stub(:add_buildpack)
          post("/buildpacks", @request_body, @headers)

          expect(last_response.status).to eq(201)
        end
      end
    end
  end
end