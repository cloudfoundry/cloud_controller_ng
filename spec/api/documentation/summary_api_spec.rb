require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make :space => space, :droplet_hash => nil, :package_state => "PENDING" }
  let(:user) { make_developer_for_space(app_obj.space) }

  authenticated_request

  get "/v2/apps/:guid/summary" do

    example "Get app summary" do
      client.get "/v2/apps/#{app_obj.guid}/summary", {},  headers
      status.should == 200
    end
  end
end

resource 'Spaces', :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:guid) { space.guid }

  authenticated_request

  get "/v2/spaces/:guid/summary" do

    example "Get space summary" do
      client.get "/v2/spaces/#{guid}/summary", {} , headers
      expect(status).to eq 200
    end
  end
end

