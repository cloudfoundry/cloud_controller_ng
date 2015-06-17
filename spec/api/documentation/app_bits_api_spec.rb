require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', type: [:api, :legacy_api] do
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
      resources: '[]',
      application: valid_zip
    }
  end

  let(:space) { VCAP::CloudController::Space.make }
  let(:app_obj) { VCAP::CloudController::AppFactory.make(space: space, droplet_hash: nil, package_state: 'PENDING') }

  authenticated_request

  parameter :guid, 'The guid of the App'
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
      { fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901' },
      { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f' }
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
              { fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901' },
              { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f' }
            ].to_json
          ]

    field :application, 'A binary zip file containing the application bits.', required: true

    example 'Uploads the bits for an App' do |example|
      explanation <<-eos
        Defines and uploads the bits (artifacts and dependencies) that this application needs to run, using a multipart PUT request.
        Bits that have already been uploaded can be referenced by their resource fingerprint(s).
        Bits that have not already been uploaded to Cloud Foundry must be included as a zipped binary file named "application".
      eos

      # rubocop:disable LineLength
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
      # rubocop:enable LineLength

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
      expect(response_headers['Location']).to include('cc-packages.s3.amazonaws.com')
      expect(status).to eq(302)
    end
  end

  get '/v2/apps/:guid/droplet/download' do
    let(:async) { false }
    let(:blobstore) do
      CloudController::DependencyLocator.instance.droplet_blobstore
    end

    before do
      app_obj.droplet_hash = 'abcdef'
      app_obj.save

      droplet_file = Tempfile.new(app_obj.guid)
      droplet_file.write('droplet contents')
      droplet_file.close

      droplet = CloudController::DropletUploader.new(app_obj, blobstore)
      droplet.upload(droplet_file.path)
    end

    example 'Downloads the staged droplet for an App' do
      explanation <<-eos
        When using a remote blobstore, such as AWS, the response is a redirect to the actual location of the droplet.
      eos

      client.get "/v2/apps/#{app_obj.guid}/droplet/download", {}, headers
      expect(status).to eq(302)
      expect(response_headers['Location']).to include('cc-droplets.s3.amazonaws.com')
    end
  end

  post '/v2/apps/:guid/copy_bits' do
    let(:src_app) { VCAP::CloudController::AppFactory.make }
    let(:dest_app) { VCAP::CloudController::AppFactory.make }
    let(:json_payload) { { source_app_guid: src_app.guid }.to_json }

    field :source_app_guid, 'The guid for the source app', required: true

    example 'Copy the app bits for an App' do
      explanation <<-eos
        This endpoint will copy the package bits in the blobstore from the source app to the destination app.
        It will always return a job which you can query for success or failure.
        This operation will require the app to restart in order for the changes to take effect.
      eos

      blobstore = double(:blobstore, cp_file_between_keys: nil)
      stub_const('CloudController::Blobstore::Client', double(:blobstore_client, new: blobstore))

      dest_app.update(package_updated_at: dest_app.package_updated_at - 1)
      client.post "/v2/apps/#{dest_app.guid}/copy_bits", json_payload, headers

      expect(status).to eq(201)
    end
  end
end
