require 'spec_helper'
require 'cloud_controller/opi/stager_client'

RSpec.describe(OPI::StagerClient) do
  let(:eirini_url) { 'http://eirini.loves.heimdall:777' }
  let(:staging_details) { stub_staging_details }
  let(:staging_request) { stub_staging_request_hash }

  let(:protocol) { instance_double(VCAP::CloudController::Diego::Protocol) }
  let(:config) { instance_double(VCAP::CloudController::Config) }

  subject(:stager_client) { described_class.new(eirini_url, config) }

  context 'when staging an app' do
    before do
      allow(VCAP::CloudController::Diego::Protocol).to receive(:new).and_return(protocol)
      allow(config).to receive(:get).
        with(:opi, :cc_uploader_url).
        and_return('https://cc-uploader.service.cf.internal:9091')
      allow(protocol).to receive(:stage_package_request).
        with(config, staging_details).
        and_return(staging_request)

      stub_request(:post, "#{eirini_url}/stage/guid").
        to_return(status: 202)
    end

    it 'should send the expected request' do
      stager_client.stage('guid', staging_details)
      expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/guid").with(body: {
        app_id: 'thor',
        file_descriptors: 2,
        memory_mb: 420,
        disk_mb: 42,
        environment: [{ 'name' => 'eirini', 'value' => 'some' }],
        timeout: 10,
        log_guid: 'is the actual app id',
        lifecycle: 'example-lifecycle',
        completion_callback: 'completed',
        lifecycle_data: { 'droplet_upload_uri' => 'https://cc-uploader.service.cf.internal:9091/v1/droplet/guid?cc-droplet-upload-uri=example.com/upload' },
        egress_rules: ['rule-1', 'rule-2'],
        isolation_segment: 'isolation'
      }.to_json
      )
    end

    context 'when the response contains an error' do
      before do
        stub_request(:post, "#{eirini_url}/stage/guid").
          to_return(status: 501, body: { 'error' => 'argh' }.to_json)
      end

      it 'should raise an error' do
        expect { stager_client.stage('guid', staging_details) }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  def stub_staging_request_hash
    {
        app_id: 'thor',
        file_descriptors: 2,
        memory_mb: 420,
        disk_mb: 42,
        environment: [{ 'name' => 'eirini', 'value' => 'some' }],
        timeout: 10,
        log_guid: 'is the actual app id',
        lifecycle: 'example-lifecycle',
        completion_callback: 'completed',
        lifecycle_data: {
          droplet_upload_uri: 'example.com/upload'
        },
        egress_rules: ['rule-1', 'rule-2'],
        isolation_segment: 'isolation'
    }
  end

  def stub_staging_details
    staging_details                                 = VCAP::CloudController::Diego::StagingDetails.new
    staging_details.staging_guid                    = 'thor'
    staging_details.staging_memory_in_mb            = 420
    staging_details.staging_disk_in_mb              = 42
    staging_details.environment_variables           = { 'doesnt': 'matter' }
    staging_details
  end
end
