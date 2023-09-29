require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Apps', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:tmpdir) { Dir.mktmpdir }
  let(:valid_zip) do
    zip_name = File.join(tmpdir, 'file.zip')
    TestZip.create(zip_name, 1, 1024)
    zip_file = File.new(zip_name)
    Rack::Test::UploadedFile.new(zip_file)
  end

  let(:req_body) do
    {
      resources: '[]',
      application: valid_zip
    }
  end

  let(:space) { VCAP::CloudController::Space.make }
  let(:process) { VCAP::CloudController::ProcessModelFactory.make(space:) }

  authenticated_request

  parameter :guid, 'The guid of the App'
  let(:async) { true }
  let(:app_bits_put_params) do
    {
      async: async,
      resources: fingerprints.to_json,
      application: valid_zip
    }
  end

  let(:fingerprints) do
    [
      { fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901' },
      { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f' }
    ]
  end

  before do
    TestConfig.override(
      directories: { tmpdir: File.dirname(valid_zip.path) },
      kubernetes: {}
    )
  end

  put '/v2/apps/:guid/bits' do
    async_description = <<-EOS
      If true, a new asynchronous job is submitted to persist the bits and the job id is included in the response.
      The client will need to poll the job's status until persistence is completed successfully.
      If false, the request will block until the bits are persisted synchronously.
      Defaults to false.
    EOS
    parameter :async, async_description

    resources_desc = <<-EOS
      Fingerprints of the application bits that have previously been pushed to Cloud Foundry.
      Each fingerprint must include the file path, sha1 hash, and file size in bytes.
      Each fingerprint may include the file mode, which must be an octal string with at least read and write permissions for owners.
      If a mode is not provided, the default mode of 0744 will be used.
      Fingerprinted bits MUST exist in the Cloud Foundry resource cache or the request (or job, if async) will fail.
    EOS
    field :resources, resources_desc,
          required: true,
          example_values: [
            [
              { fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901' },
              { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f' },
              { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f', mode: '644' }
            ].to_json
          ]

    field :application, 'A binary zip file containing the application bits.', required: true

    example 'Uploads the bits for an App' do |example|
      explanation <<-EOS
        Defines and uploads the bits (artifacts and dependencies) that this application needs to run, using a multipart PUT request.
        Bits that have already been uploaded can be referenced by their resource fingerprint(s).
        Bits that have not already been uploaded to Cloud Foundry must be included as a zipped binary file named "application".
        File mode bits are only presevered for applications run on a Diego backend. If left blank, mode will default to 749, which
        are also the default bits for a DEA backend. File mode bits are required to have at least the minimum permissions of 0600.
      EOS

      request_body_example = <<-EOS.gsub(/^ */, '')
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

      client.put "/v2/apps/#{process.guid}/bits", app_bits_put_params, headers
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
      explanation <<-EOS
        When using a remote blobstore, such as AWS, the response is a redirect to the actual location of the bits.
        If the client is automatically following redirects, then the OAuth token that was used to communicate with Cloud Controller will be replayed on the new redirect request.
        Some blobstores may reject the request in that case. Clients may need to follow the redirect without including the OAuth token.
      EOS

      no_doc { client.put "/v2/apps/#{process.guid}/bits", app_bits_put_params, headers }
      client.get "/v2/apps/#{process.guid}/download", {}, headers
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
      droplet_file = Tempfile.new(process.guid)
      droplet_file.write('droplet contents')
      droplet_file.close

      VCAP::CloudController::Jobs::V3::DropletUpload.new(droplet_file.path, process.desired_droplet.guid, skip_state_transition: false).perform
    end

    example 'Downloads the staged droplet for an App' do
      explanation <<-EOS
        When using a remote blobstore, such as AWS, the response is a redirect to the actual location of the bits.
        If the client is automatically following redirects, then the OAuth token that was used to communicate with Cloud Controller will be replayed on the new redirect request.
        Some blobstores may reject the request in that case. Clients may need to follow the redirect without including the OAuth token.
      EOS

      client.get "/v2/apps/#{process.guid}/droplet/download", {}, headers
      expect(status).to eq(302)
      expect(response_headers['Location']).to include('cc-droplets.s3.amazonaws.com')
    end
  end

  post '/v2/apps/:guid/copy_bits' do
    let(:src_process) { VCAP::CloudController::ProcessModelFactory.make }
    let(:dest_process) { VCAP::CloudController::ProcessModelFactory.make }
    let(:json_payload) { { source_app_guid: src_process.guid }.to_json }

    field :source_app_guid, 'The guid for the source app', required: true

    let(:raw_post) { body_parameters }

    example 'Copy the app bits for an App' do
      explanation <<-EOS
        This endpoint will copy the package bits in the blobstore from the source app to the destination app.
        It will always return a job which you can query for success or failure.
        This operation will require the app to restart in order for the changes to take effect.
      EOS

      blobstore = double(:blobstore, cp_file_between_keys: nil)
      stub_const('CloudController::Blobstore::Client', double(:blobstore_client, new: blobstore))

      dest_process.update(package_updated_at: dest_process.package_updated_at - 1)
      client.post "/v2/apps/#{dest_process.guid}/copy_bits", json_payload, headers

      expect(status).to eq(201)
    end
  end
end
