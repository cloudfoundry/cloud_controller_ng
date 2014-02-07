require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Buildpacks (experimental)", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let!(:buildpacks) { (1..3).map { |i| VCAP::CloudController::Buildpack.make(name: "name_#{i}", position: i) } }
  let(:guid) { buildpacks.first.guid }

  authenticated_request

  field :guid, "The guid of the buildpack.", required: false
  field :name, "The name of the buildpack. To be used by app buildpack field. (only alphanumeric characters)", required: true, example_values: ["Golang_buildpack"]
  field :position, "The order in which the buildpacks are checked during buildpack auto-detection.", required: false
  field :enabled, "Whether or not the buildpack will be used for staging", required: false, default: true
  field :filename, "The name of the uploaded buildpack file", required: false

  standard_model_list(:buildpack, VCAP::CloudController::BuildpacksController)
  standard_model_get(:buildpack)
  standard_model_delete(:buildpack)

  post "/v2/buildpacks" do
    example "Creates an admin buildpack" do
      client.post "/v2/buildpacks", fields_json, headers
      expect(status).to eq 201
      standard_entity_response parsed_response, :buildpack, name: "Golang_buildpack"
    end
  end

  put "/v2/buildpacks" do
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
        client.put "/v2/buildpacks/#{guid}", Yajl::Encoder.encode(position: 3), headers
        status.should == 201
        standard_entity_response parsed_response, :buildpack, position: 3
      }.to change {
        VCAP::CloudController::Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
      }.from(
        [["name_1", 1], ["name_2", 2], ["name_3", 3]]
      ).to(
        [["name_2", 1], ["name_3", 2], ["name_1", 3]]
      )
    end

    example "Enable or disable a buildpack" do
      expect {
        client.put "/v2/buildpacks/#{guid}", Yajl::Encoder.encode(enabled: false), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :buildpack, enabled: false
      }.to change {
        VCAP::CloudController::Buildpack.find(guid: guid).enabled
      }.from(true).to(false)

      expect {
        client.put "/v2/buildpacks/#{guid}", Yajl::Encoder.encode(enabled: true), headers
        expect(status).to eq 201
        standard_entity_response parsed_response, :buildpack, enabled: true
      }.to change {
        VCAP::CloudController::Buildpack.find(guid: guid).enabled
      }.from(false).to(true)
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
        client.put "/v2/buildpacks/#{guid}/bits", {buildpack: valid_zip}, headers
      end

      status.should == 201
      standard_entity_response parsed_response, :buildpack
    end
  end
end
