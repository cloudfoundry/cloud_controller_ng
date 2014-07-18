require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', :type => :api do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:tmpdir) { Dir.mktmpdir }
  let(:valid_zip) {
    zip_name = File.join(tmpdir, 'file.zip')
    TestZip.create(zip_name, 1, 1024)
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

  parameter :guid, "The guid of the App"
  let(:async) { true }
  let(:app_bits_put_params) do
    {
        async: async,
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
    parameter :async, async_description

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

    example 'Uploads the bits for an App' do |example|
      explanation <<-eos
        Defines and uploads the bits (artifacts and dependencies) that this application needs to run, using a multipart PUT request.
        Bits that have already been uploaded can be referenced by their resource fingerprint(s).
        Bits that have not already been uploaded to Cloud Foundry must be included as a zipped binary file named "application".
      eos

      request_body_example = <<-eos.gsub(/^ */, '')
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
      eos

      client.put "/v2/apps/#{app_obj.guid}/bits", app_bits_put_params, headers
      example.metadata[:requests].each do |req|
        req[:request_body] = request_body_example
        req[:curl] = nil
      end
      expect(status).to eq(201)
    end
  end

  get '/v2/apps/:guid/download' do
    let(:async) { false }

    example 'Downloads the bits for an App' do
      explanation <<-eos
        When using a remote blobstore, such as AWS, the response is a redirect to the actual location of the bits.
      eos

      no_doc { client.put "/v2/apps/#{app_obj.guid}/bits", app_bits_put_params, headers }
      client.get "/v2/apps/#{app_obj.guid}/download", {}, headers
      expect(response_headers["Location"]).to include("cc-packages.s3.amazonaws.com")
      expect(status).to eq(302)
    end
  end
end
