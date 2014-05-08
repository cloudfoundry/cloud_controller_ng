require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make :space => space, :package_state => "STAGED" }
  let(:user) { make_developer_for_space(app_obj.space) }

  authenticated_request

  post "/v2/apps/:guid/restage" do
    example "Restage an app" do
      client.post "/v2/apps/#{app_obj.guid}/restage", {},  headers
      status.should == 201
    end
  end
end
