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
    example "Get all feature flags" do
      VCAP::CloudController::FeatureFlag.create(name: "private_domain_creation", enabled: false)

      client.get "/v2/config/feature_flags", {}, headers

      expect(status).to eq(200)
      expect(parsed_response.length).to eq(2)
      expect(parsed_response).to include(
        {
          'name'          => 'user_org_creation',
          'default_value' => false,
          'enabled'       => false,
          'overridden'    => false,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
      expect(parsed_response).to include(
        {
          'name'          => 'private_domain_creation',
          'default_value' => true,
          'enabled'       => false,
          'overridden'    => true,
          'url'           => '/v2/config/feature_flags/private_domain_creation'
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
          'overridden'    => true,
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
          'overridden'    => false,
          'url'           => '/v2/config/feature_flags/user_org_creation'
        })
    end
  end

  delete "/v2/config/feature_flags/:name" do
    include_context "name_parameter"

    example "Unset a feature flag" do
      VCAP::CloudController::FeatureFlag.create(name: "private_domain_creation", enabled: false)
      client.delete "/v2/config/feature_flags/private_domain_creation", "{}", headers
      expect(status).to eq(204)
      expect(VCAP::CloudController::FeatureFlag.find(name: "private_domain_creation")).to be_nil
    end
  end
end
