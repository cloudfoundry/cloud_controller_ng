require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Apps", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  let(:tmpdir) { Dir.mktmpdir }
  let(:valid_zip) {
    zip_name = File.join(tmpdir, "file.zip")
    create_zip(zip_name, 1)
    zip_file = File.new(zip_name)
    Rack::Test::UploadedFile.new(zip_file)
  }

  let(:req_body)  {{:resources => "[]",  :application => valid_zip}}
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make(:space => space, :droplet_hash => nil, :package_state => "PENDING") }

  authenticated_request

  field :guid, "The guid of the app.", required: true

  put "/v2/apps/:guid/bits" do
    let(:app_bits_put_params) do
      {"async" => true, 
       "resources" => [{"fn" => "path/to/content.txt", "size" => 123, "sha1" => "some sha"}].to_json, 
       "application" => valid_zip
      }
    end
    
    field :filename, "The name of the uploaded application file", required: true
    field :async, "The bits are loaded asynchronously.", required: false, example_values: ["true"]
    field :fingerprints, "The fingerprints of the files contained in the application archive", required: true, example_values: ["[{fn: path/to/content.txt, size: 123, sha1: some sha}]"]

    example "Upload the bits for an app" do
      explanation "PUT not shown because it involves putting a large zip file. Right now only zipped apps are accepted"

      no_doc do
        response = client.put "/v2/apps/#{app_obj.guid}/bits", app_bits_put_params, headers
      end
      status.should == 201
    end
  end

  get "/v2/apps/:guid/download" do
    let(:blobstore_config) do
      {
        :packages => {
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir("packages", tmpdir)
          },
          :app_package_directory_key => "cc-packages",
        },
        :resource_pool => {
          :resource_directory_key => "cc-resources",
          :fog_connection => {
            :provider => "Local",
            :local_root => Dir.mktmpdir("resourse_pool", tmpdir)
          }
        },
      }
    end

    before do
      Fog.unmock!
      @old_config = config
      config_override(blobstore_config)
      guid = app_obj.guid
      zipname = File.join(tmpdir, "test.zip")
      create_zip(zipname, 10, 1024)
      VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new(guid, zipname, []).perform
    end

    after do
      config_override(@old_config)
      FileUtils.rm_rf(tmpdir)
    end

    example "Download the bits for an app" do
      client.get "/v2/apps/#{app_obj.guid}/download", {},  headers
      status.should == 200
    end
  end
end
