require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Buildpacks", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do
      VCAP::CloudController::Buildpack.make
    end
  end

  let(:guid) { VCAP::CloudController::Buildpack.first.guid }

  standard_parameters
  response_fields_from_table :buildpack
  standard_model_object :buildpack

  post "/v2/buildpacks" do
    let(:name) { "A-buildpack-name" }

    example "Creates an admin buildpack" do
      client.post "/v2/buildpacks", Yajl::Encoder.encode(params), headers
      status.should == 201
      standard_entity_response parsed_response, :buildpack, :name => name
    end
  end
end
