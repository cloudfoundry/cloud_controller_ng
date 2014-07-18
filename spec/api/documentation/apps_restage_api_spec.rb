require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make :space => space, :package_state => "STAGED" }
  let(:user) { make_developer_for_space(app_obj.space) }

  authenticated_request

  parameter :guid, "The guid of the App"
  post "/v2/apps/:guid/restage" do
    example "Restage an App" do
      client.post "/v2/apps/#{app_obj.guid}/restage", {},  headers
      expect(status).to eq(201)
    end
  end
end
