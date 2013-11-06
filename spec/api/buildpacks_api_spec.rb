require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Buildpacks (experimental)", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do |i|
      i += 1
      VCAP::CloudController::Buildpack.make(name: "name_#{i}", position: i)
    end
  end

  let(:guid) { VCAP::CloudController::Buildpack.first.guid }

  standard_parameters VCAP::CloudController::BuildpacksController

  field :name, "The name of the buildpack. To be used by app buildpack field.", required: true
  field :position, "The order in which the buildpacks are checked during buildpack auto-detection.", required: false

  standard_model_object :buildpack

  post "/v2/buildpacks" do
    let(:name) { "A-buildpack-name" }
    let(:request) do
      {
        name: name
      }
    end

    example "Creates an admin buildpack" do
      client.post "/v2/buildpacks", Yajl::Encoder.encode(request), headers
      status.should == 201
      standard_entity_response parsed_response, :buildpack, :name => name
    end
  end

  put "/v2/buildpacks" do
    let(:position) { 3 }
    let(:request) do
      {
        guid: guid,
        position: position
      }
    end

    example "Change the position of a buildpack" do
      first = <<-DOC
        Buildpacks are maintained in an ordered list.  If the target position is already occupied,
        the entries will be shifted down the list to make room.  If the target position is beyond
        the end of the current list, the buildpack will be positioned at the end of the list.
      DOC

      second = <<-DOC
        Position 0 indicates an unpriorized buildpack.  Unprioritized buildpacks will be treated
        as if the are at the end of the list.  No ordering is implied across unprioritized buildpacks.
      DOC

      explanation [{explanation: first}, {explanation: second}]

      expect {
        client.put "/v2/buildpacks/#{guid}", Yajl::Encoder.encode(request), headers
        status.should == 201
        standard_entity_response parsed_response, :buildpack, position: position
      }.to change {
        VCAP::CloudController::Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
      }.from(
        [["name_1", 1], ["name_2", 2], ["name_3", 3]]
      ).to(
        [["name_2", 1], ["name_3", 2], ["name_1", 3]]
      )
    end
  end

  put "/v2/buildpacks/:guid/bits" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:user) { make_user }
    let(:filename) { "file.zip" }

    after { FileUtils.rm_rf(tmpdir) }

    let(:valid_zip) do
      zip_name = File.join(tmpdir, filename)
      create_zip(zip_name, 1)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    example "Upload the bits for an admin buildpack" do

      explanation "PUT not shown because it involves putting a large zip file. Right now only zipped admin buildpacks are accepted"

      no_doc do
        client.put "/v2/buildpacks/#{guid}/bits", {:buildpack => valid_zip}, headers
      end

      status.should == 201
      standard_entity_response parsed_response, :buildpack
    end
  end
end
