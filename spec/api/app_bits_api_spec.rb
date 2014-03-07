require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)['HTTP_AUTHORIZATION'] }
  let(:tmpdir) { Dir.mktmpdir }
  let(:valid_zip) {
    zip_name = File.join(tmpdir, 'file.zip')
    create_zip(zip_name, 1)
    zip_file = File.new(zip_name)
    Rack::Test::UploadedFile.new(zip_file)
  }

  let(:req_body) do
    {
      :resources => '[]',
      :application => valid_zip
    }
  end

  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make(:space => space, :droplet_hash => nil, :package_state => 'PENDING') }

  authenticated_request

  field :guid, 'The guid of the app.', required: true
  let(:app_bits_put_params) do
    {
        async: false,
        resources: fingerprints.to_json,
        application: valid_zip,
    }
  end

  let(:fingerprints) {
    [
        {fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901'},
        {fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f'}
    ]
  }

  put '/v2/apps/:guid/bits' do
    async_description = <<-eos
      If true, a new asynchronous job is submitted to persist the bits and the job id is included in the response.
      The client will need to poll the job's status until persistence is completed successfully.
      If false, the request will block until the bits are persisted synchronously.
      Defaults to false.
    eos
    field :async, async_description, required: false, example_values: [true]

    resources_desc = <<-eos
      Fingerprints of the application bits that have previously been pushed to Cloud Foundry.
      Each fingerprint must include the file path, sha1 hash, and file size in bytes.
      Fingerprinted bits MUST exist in the Cloud Foundry resource cache or the request (or job, if async) will fail.
    eos
    field :resources, resources_desc,
          required: true,
          example_values: [
            [
              {fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901'},
              {fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f'}
            ].to_json
          ]

    field :application, 'A binary zip file containing the application bits.', required: true

    explanation = <<-eos
      Defines and uploads the bits (artifacts and dependencies) that this application needs to run, using a multipart PUT request.
      Bits that have already been uploaded can be referenced by their resource fingerprint(s).
      Bits that have not already been uploaded to Cloud Foundry must be included as a zipped binary file named "application".
    eos

    request_body_example = <<EOS
--AaB03x
Content-Disposition: form-data; name="async"

true
--AaB03x
Content-Disposition: form-data; name="resources"

[{"fn":"path/to/content.txt","size":123,"sha1":"b907173290db6a155949ab4dc9b2d019dea0c901"},{"fn":"path/to/code.jar","size":123,"sha1":"ff84f89760317996b9dd180ab996b079f418396f"}]
--AaB03x
Content-Disposition: form-data; name="application"; filename="application.zip"
Content-Type: application/zip
Content-Length: 123
Content-Transfer-Encoding: binary

&lt;&lt;binary artifact bytes&gt;&gt;
--AaB03x
EOS

    example 'Uploads the bits for an app' do
      explanation explanation
      client.put "/v2/apps/#{app_obj.guid}/bits", app_bits_put_params, headers
      example.metadata[:requests].each do |req|
        req[:request_body] = request_body_example
        req[:curl] = nil
      end
      status.should == 201
    end
  end

  get '/v2/apps/:guid/download' do
    let(:blobstore_config) do
      {
        :packages => {
          :fog_connection => {
            :provider => 'Local',
            :local_root => Dir.mktmpdir('packages', tmpdir)
          },
          :app_package_directory_key => 'cc-packages',
        },
        :resource_pool => {
          :resource_directory_key => 'cc-resources',
          :fog_connection => {
            :provider => 'Local',
            :local_root => Dir.mktmpdir('resourse_pool', tmpdir)
          }
        },
      }
    end

    before do
      Fog.unmock!
      @old_config = config
      config_override(blobstore_config)
      guid = app_obj.guid
      zipname = File.join(tmpdir, 'test.zip')
      create_zip(zipname, 10, 1024)
      VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new(guid, zipname, []).perform
    end

    after do
      config_override(@old_config)
      FileUtils.rm_rf(tmpdir)
    end

    example 'Downloads the bits for an app' do
      client.get "/v2/apps/#{app_obj.guid}/download", {},  headers
      status.should == 200
    end
  end
end
