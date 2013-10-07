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

  field :name, "The name of the buildpack. To be used by app buildpack field.", required: true
  field :priority, "The order in which the buildpacks are checked during buildpack auto-detection.", required: false, readonly: true

  standard_model_object :buildpack

  post "/v2/buildpacks" do
    let(:name) { "A-buildpack-name" }

    example "Creates an admin buildpack" do
      client.post "/v2/buildpacks", Yajl::Encoder.encode(params), headers
      status.should == 201
      standard_entity_response parsed_response, :buildpack, :name => name
    end
  end

  post "/v2/buildpacks/:guid/bits" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:user) { make_user }
    let(:filename) { "file.zip" }

    after { FileUtils.rm_rf(tmpdir) }

    let(:valid_zip) do
      zip_name = File.join(tmpdir, filename)
      create_zip(zip_name, 1)
      zip_file = File.new(zip_name)
      p zip_name
      Rack::Test::UploadedFile.new(zip_file)
    end

    example "Upload the bits for an admin buildpack" do

      explanation "POST not shown because it involves posting a large zip file. Right now only zipped admin buildpacks are accepted"

      no_doc do
        client.post "/v2/buildpacks/#{guid}/bits", {:buildpack => valid_zip}, headers
      end

      status.should == 201
      standard_entity_response parsed_response, :buildpack
    end
  end
end
