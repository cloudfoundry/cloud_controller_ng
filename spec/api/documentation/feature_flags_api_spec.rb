require "spec_helper"
require "rspec_api_documentation/dsl"

resource "Feature Flags (experimental)", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make }

  authenticated_request

  shared_context "name_parameter" do
    parameter :name, "The name of the Feature Flag"
  end

  shared_context "updatable_fields" do
    field :enabled, "The state of the feature flag.", required: true, example_values: [true, false]
  end

  get "/v2/config/feature_flags" do
    example "Return the feature flags for CC" do
      client.get "/v2/config/feature_flags", {}, headers
      expect(status).to eq(200)
      standard_list_response parsed_response, :feature_flag
    end
  end

  describe "Org User Creation" do
    let!(:user_org_creation_feature_flag) { VCAP::CloudController::FeatureFlag.make(:name => "user_org_creation") }
    include_context "name_parameter"
    include_context "updatable_fields"

    put "/v2/config/feature_flags/user_org_creation" do
      example "Set the enabled column on the named feature flag" do
        client.put "/v2/config/feature_flags/user_org_creation", fields_json, headers
        expect(status).to eq(200)
        standard_entity_response parsed_response, :feature_flag
      end
    end
  end
end
