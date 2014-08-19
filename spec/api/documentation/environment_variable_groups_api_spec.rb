require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Environment Variable Groups (Experimental)", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:staging_group) { VCAP::CloudController::EnvironmentVariableGroup.staging }
  let(:running_group) { VCAP::CloudController::EnvironmentVariableGroup.running }

  authenticated_request

  describe "Standard endpoints" do
    get "/v2/config/environment_variable_groups/staging" do
      example "Getting the contents of the staging environment variable group" do

        explanation "returns the set of default environment variables available during staging"

        staging_group.update(environment_json: {
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })

        client.get "/v2/config/environment_variable_groups/staging", {}, headers
        expect(status).to eq(200)
        expect(parsed_response).to eq({
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })
      end
    end
    
    get "/v2/config/environment_variable_groups/running" do
      example "Getting the contents of the running environment variable group" do
        explanation "returns the set of default environment variables available to running apps"

        running_group.update(environment_json: {
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })

        client.get "/v2/config/environment_variable_groups/running", {}, headers
        expect(status).to eq(200)
        expect(parsed_response).to eq({
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })
      end
    end

    put "/v2/config/environment_variable_groups/running" do
      example "Updating the contents of the running environment variable group" do
        explanation "Updates the set of environment variables which will be made available to all running apps"

        client.put "/v2/config/environment_variable_groups/running", '{ "abc": 123, "do-re-me": "far-so-la-tee" }', headers
        expect(status).to eq(200)
        expect(parsed_response).to eq({
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })
      end
    end

    put "/v2/config/environment_variable_groups/staging" do
      example "Updating the contents of the staging environment variable group" do
        explanation "Updates the set of environment variables which will be made available during staging"

        client.put "/v2/config/environment_variable_groups/staging", '{ "abc": 123, "do-re-me": "far-so-la-tee" }', headers
        expect(status).to eq(200)
        expect(parsed_response).to eq({
          "abc" => 123,
          "do-re-me" => "far-so-la-tee"
        })
      end
    end
  end
end
