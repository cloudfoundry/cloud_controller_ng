require "spec_helper"
require "membrane"

module VCAP::CloudController
  describe StagingCompletionController do

    let(:url) { "/internal/staging/completed" }

    let(:backend) { instance_double(Diego::Backend, staging_complete: nil, start: nil) }

    let(:buildpack) { Buildpack.make }
    let(:staged_app) { AppFactory.make(staging_task_id: "task-1", state: "STARTED", package_state: "PENDING") }

    let(:app_id) { staged_app.guid }
    let(:task_id) { staged_app.staging_task_id }
    let(:buildpack_key) { buildpack.key }
    let(:detected_buildpack) { "detected_buildpack" }
    let(:execution_metadata) { "execution_metadata" }

    let(:staging_response) do
      {
        "app_id" => app_id,
        "task_id" => task_id,
        "buildpack_key" => buildpack_key,
        "detected_buildpack" => detected_buildpack,
        "execution_metadata" => execution_metadata
      }
    end

    before do
      @internal_user = "internal_user"
      @internal_password = "internal_password"
      authorize @internal_user, @internal_password

      allow_any_instance_of(Backends).to receive(:diego_backend).and_return(backend)
    end

    describe "authentication" do
      context "when missing authentication" do
        it "fails with authentication required" do
          header("Authorization", nil)
          post url, staging_response
          expect(last_response.status).to eq(401)
        end
      end

      context "when using invalid credentials" do
        it "fails with authenticatiom required" do
          authorize "bar", "foo"
          post url, staging_response
          expect(last_response.status).to eq(401)
        end
      end

      context "when using valid credentials" do
        it "succeeds" do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
      end
    end

    describe "validation" do
      context "when sending invalid json" do
        it "fails with a 400" do
          post url, "this is not json"

          expect(last_response.status).to eq(400)
          expect(last_response.body).to match /MessageParseError/
        end
      end
    end

    it "calls the backend handler with the staging response" do
      expect(backend).to receive(:staging_complete).with(staging_response)

      post url, MultiJson.dump(staging_response)
      expect(last_response.status).to eq(200)
    end

    it "propagates api errors from staging_response" do
      expect(backend).to receive(:staging_complete).and_raise(Errors::ApiError.new_from_details("JobTimeout"))

      post url, MultiJson.dump(staging_response)
      expect(last_response.status).to eq(524)
      expect(last_response.body).to match /JobTimeout/
    end
  end
end
