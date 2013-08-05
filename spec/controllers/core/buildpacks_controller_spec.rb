require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::BuildpacksController, type: :controller do
    include_examples "creating", path: "/v2/buildpacks", model: Models::Buildpack,
                     required_attributes: %w(name url),
                     unique_attributes: %w(name)

    describe "POST /v2/buildpacks" do
      before do
        @attributes = {"name" => "My Buildpack", "url" => "https://example.com/repo.git"}
        @request_body = Yajl::Encoder.encode(@attributes)
      end

      after do
        reset_database
      end

      context "as a basic user" do
        it "returns 403" do
          @user = Models::User.make(admin: false)

          post("/v2/buildpacks", @request_body, json_headers(headers_for @user))

          expect(last_response.status).to eq(403)
        end
      end

      context "as an admin" do
        before do
          @admin = Models::User.make(admin: true)
          @headers = json_headers(headers_for(@admin))
        end

        it "posts a message to nats" do
          DeaClient.should_receive(:add_buildpack).with(@attributes["name"], @attributes["url"])

          post("/v2/buildpacks", @request_body, @headers)
        end

        it "returns 201" do
          DeaClient.stub(:add_buildpack)
          post("/v2/buildpacks", @request_body, @headers)

          expect(last_response.status).to eq(201)
        end
      end
    end
  end
end