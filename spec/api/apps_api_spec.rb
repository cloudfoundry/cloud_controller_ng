require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do
      VCAP::CloudController::App.make
    end
  end

  let(:admin_buildpack) { VCAP::CloudController::Buildpack.make }

  let(:guid) { VCAP::CloudController::App.first.guid }

  standard_parameters
  response_fields_from_table :app
  standard_model_object :app # adds get /v2/users/ and get /v2/users/:guid

  put "/v2/apps/:guid" do
    let(:buildpack) { "http://github.com/a-buildpack" }

    example "Set a custom buildpack URL for an Application" do

      explanation <<EOD
PUT with the buildpack attribute set to the URL of a git repository to set a custom buildpack.
EOD

      client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(params), headers
      status.should == 201
      standard_entity_response parsed_response, :app, :buildpack => buildpack
    end
  end

  put "/v2/apps/:guid" do
    let(:buildpack) { admin_buildpack.name }

    example "Set a admin buildpack for an Application (by sending the name of an existing buildpack)" do

      explanation <<EOD
When the buildpack name matches the name of an admin buildpack, an admin buildpack is used rather than a
custom buildpack. The 'buildpack' column returns the name of the configured admin buildpack
EOD

      client.put "/v2/apps/#{guid}", Yajl::Encoder.encode(params), headers
      status.should == 201
      standard_entity_response parsed_response, :app, :buildpack => admin_buildpack.name
    end
  end
end
