require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Feature Flags (experimental)", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }

  authenticated_request

  shared_context "name_parameter" do
    parameter :name, "The name of the Feature Flag"
  end

  shared_context "updatable_fields" do
    field :enabled, "The state of the feature flag.", required: true, example_values: [true, false]
  end

  get "/v2/config/feature_flags" do
    let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make }

    example "Get all feature flags" do
      client.get "/v2/config/feature_flags", {}, headers

      expect(status).to eq(200)
      expect(parsed_response.length).to eq(1)
      expect(parsed_response).to include(
        {
          'name'          => feature_flag.name,
          'default_value' => false,
          'enabled'       => feature_flag.enabled,
          'url'           => "/v2/config/feature_flags/#{feature_flag.name}"
        })
    end
  end

  put "/v2/config/feature_flags/user_org_creation" do
    include_context "name_parameter"
    include_context "updatable_fields"

    example "Enable a feature flag" do
      client.put "/v2/config/feature_flags/user_org_creation", fields_json, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'user_org_creation',
          'default_value' => false,
          'enabled'       => true,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
    end
  end

  get "/v2/config/feature_flags/user_org_creation" do
    include_context "name_parameter"

    example "Get a feature flag" do
      client.get "/v2/config/feature_flags/user_org_creation", {}, headers

      expect(status).to eq(200)
      expect(parsed_response).to eq(
        {
          'name'          => 'user_org_creation',
          'default_value' => false,
          'enabled'       => false,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
    end
  end
end
