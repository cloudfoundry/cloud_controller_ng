require 'spec_helper'
require 'cloud_controller/opi/apps_client'

RSpec.describe(OPI::Client) do
  describe 'can desire an app' do
    subject(:client) { described_class.new(opi_url) }
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }
    let(:img_url) { 'http://example.org/image1234' }
    let(:droplet) { VCAP::CloudController::DropletModel.make(
      docker_receipt_image: 'http://example.org/image1234',
      droplet_hash: 'd_haash',
      guid: 'some-droplet-guid',
    )
    }

    let(:cfg) { ::VCAP::CloudController::Config.new({ default_health_check_timeout: 99 }) }
    let(:lifecycle_type) { nil }
    let(:app_model) {
      ::VCAP::CloudController::AppModel.make(lifecycle_type,
                                             guid: 'app-guid',
                                             droplet: droplet,
                                             enable_ssh: false,
                                             environment_variables: { 'BISH': 'BASH', 'FOO': 'BAR' })
    }

    let(:lrp) do
      lrp = ::VCAP::CloudController::ProcessModel.make(:process,
        app:                  app_model,
        state:                'STARTED',
        diego:                false,
        guid:                 'process-guid',
        type:                 'web',
        health_check_timeout: 12,
        instances:            21,
        memory:               128,
        disk_quota:           256,
        command:              'ls -la',
        file_descriptors:     32,
        health_check_type:    'port',
        enable_ssh:           false,
      )
      lrp.this.update(updated_at: Time.at(2))
      lrp.reload
    end

    context 'when request executes successfully' do
      before do
        stub_request(:put, "#{opi_url}/apps/process-guid-#{lrp.version}").to_return(status: 201)
      end

      let(:expected_body) {
        {
            process_guid: "process-guid-#{lrp.version}",
            docker_image: 'http://example.org/image1234',
            start_command: 'ls -la',
            environment: {
              'BISH': 'BASH',
              'FOO': 'BAR',
              'VCAP_APPLICATION': %{
                  {
                    "cf_api": "http://api2.vcap.me",
                    "limits": {
                      "fds": 32,
                      "mem": 128,
                      "disk": 256
                     },
                    "application_name": "#{app_model.name}",
                    "application_uris":[],
                    "name": "#{app_model.name}",
                    "space_name": "#{lrp.space.name}",
                    "space_id": "#{lrp.space.guid}",
                    "uris": [],
                    "application_id": "#{lrp.guid}",
                    "version": "#{lrp.version}",
                    "application_version": "#{lrp.version}"
                  }}.delete(' ').delete("\n"),
              'MEMORY_LIMIT': '128m',
              'VCAP_SERVICES': '{}',
              'PORT': '8080',
              'VCAP_APP_PORT': '8080',
              'VCAP_APP_HOST': '0.0.0.0'
            },
            instances: 21,
            droplet_hash: lrp.droplet_hash,
            droplet_guid: 'some-droplet-guid',
            health_check_type: 'port',
            health_check_http_endpoint: nil,
            health_check_timeout_ms: 12000,
            last_updated: '2.0',
        }
      }

      it 'sends a PUT request' do
        response = client.desire_app(lrp)

        expect(response.status_code).to equal(201)
        expect(WebMock).to have_requested(:put, "#{opi_url}/apps/process-guid-#{lrp.version}").with(body: MultiJson.dump(expected_body))
      end
    end
  end

  describe 'can fetch scheduling infos' do
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }

    let(:expected_body) { { desired_lrp_scheduling_infos: [
      { desired_lrp_key: { process_guid: 'guid_1234', annotation: '1111111111111.1' } },
      { desired_lrp_key: { process_guid: 'guid_5678', annotation: '222222222222222.2' } }
    ] }.to_json
    }

    subject(:client) {
      described_class.new(opi_url)
    }

    context 'when request executes successfully' do
      before do
        stub_request(:get, "#{opi_url}/apps").
          to_return(status: 200, body: expected_body)
      end

      it 'returns the expected scheduling infos' do
        scheduling_infos = client.fetch_scheduling_infos
        expect(WebMock).to have_requested(:get, "#{opi_url}/apps")

        expect(scheduling_infos).to match_array([
          OpenStruct.new(desired_lrp_key: OpenStruct.new(process_guid: 'guid_1234', annotation: '1111111111111.1')),
          OpenStruct.new(desired_lrp_key: OpenStruct.new(process_guid: 'guid_5678', annotation: '222222222222222.2'))
        ])
      end
    end
  end

  describe '#update_app' do
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }
    subject(:client) { described_class.new(opi_url) }

    let(:existing_lrp) { double }
    let(:process) {
      double(guid: 'guid-1234', desired_instances: 5, updated_at: Time.at(1529064800.9))
    }
    let(:routing_info) {
      instance_double(VCAP::CloudController::Diego::Protocol::RoutingInfo)
    }

    before do
      routes = {
            'http_routes' => [
              {
                'hostname'          => 'numero-uno.example.com',
                'port'              => 8080
              },
              {
                'hostname'          => 'numero-dos.example.com',
                'port'              => 8080
              }
            ]
      }

      allow(routing_info).to receive(:routing_info).and_return(routes)
      allow(VCAP::CloudController::Diego::Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info)

      stub_request(:post, "#{opi_url}/apps/guid-1234").
        to_return(status: 200)
    end

    context 'when request contains updated instances and routes' do
      let(:expected_body) {
        {
            process_guid: 'guid-1234',
            update: {
              instances: 5,
              routes: {
                'cf-router' => [
                  {
                    'hostnames'         => ['numero-uno.example.com'],
                    'port'              => 8080
                  },
                  {
                    'hostnames'         => ['numero-dos.example.com'],
                    'port'              => 8080
                  }
                ]
              },
              annotation: '1529064800.9'
            }
        }.to_json
      }

      it 'executes an http request with correct instances and routes' do
        client.update_app(process, existing_lrp)
        expect(WebMock).to have_requested(:post, "#{opi_url}/apps/guid-1234").
          with(body: expected_body)
      end

      it 'propagates the response' do
        response = client.update_app(process, existing_lrp)

        expect(response.status_code).to equal(200)
        expect(response.body).to be_empty
      end
    end

    context 'when request does not contain routes' do
      let(:expected_body) {
        {
            process_guid: 'guid-1234',
            update: {
              instances: 5,
              routes: { 'cf-router' => [] },
              annotation: '1529064800.9'
            }
        }.to_json
      }

      before do
        allow(routing_info).to receive(:routing_info).and_return({})
      end

      it 'executes an http request with empty cf-router entry' do
        client.update_app(process, existing_lrp)
        expect(WebMock).to have_requested(:post, "#{opi_url}/apps/guid-1234").
          with(body: expected_body)
      end

      it 'propagates the response' do
        response = client.update_app(process, existing_lrp)

        expect(response.status_code).to equal(200)
        expect(response.body).to be_empty
      end
    end

    context 'when the response has an error' do
      let(:expected_body) do
        { error: { message: 'reasons for failure' } }.to_json
      end

      before do
        stub_request(:post, "#{opi_url}/apps/guid-1234").
          to_return(status: 400, body: expected_body)
      end

      it 'raises ApiError' do
        expect { client.update_app(process, existing_lrp) }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  describe '#get_app' do
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }
    subject(:client) { described_class.new(opi_url) }
    let(:process) { double(guid: 'guid-1234') }

    context 'when the app exists' do
      let(:desired_lrp) {
        { process_guid: 'guid-1234', instances: 5 }
      }

      let(:expected_body) {
        { desired_lrp: desired_lrp }.to_json
      }
      before do
        stub_request(:get, "#{opi_url}/apps/guid-1234").
          to_return(status: 200, body: expected_body)
      end

      it 'executes an HTTP request' do
        client.get_app(process)
        expect(WebMock).to have_requested(:get, "#{opi_url}/apps/guid-1234")
      end

      it 'returns the desired lrp' do
        desired_lrp = client.get_app(process)
        expect(desired_lrp.process_guid).to eq('guid-1234')
        expect(desired_lrp.instances).to eq(5)
      end
    end

    context 'when the app does not exist' do
      before do
        stub_request(:get, "#{opi_url}/apps/guid-1234").
          to_return(status: 404)
      end

      it 'executed and HTTP request' do
        client.get_app(process)
        expect(WebMock).to have_requested(:get, "#{opi_url}/apps/guid-1234")
      end

      it 'returns nil' do
        desired_lrp = client.get_app(process)
        expect(desired_lrp).to be_nil
      end
    end
  end

  context 'stop an app' do
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }
    subject(:client) { described_class.new(opi_url) }

    before do
      stub_request(:put, "#{opi_url}/apps/guid-1234/stop").
        to_return(status: 200)
    end

    it 'executes an HTTP request' do
      client.stop_app('guid-1234')
      expect(WebMock).to have_requested(:put, "#{opi_url}/apps/guid-1234/stop")
    end

    it 'returns status OK' do
      response = client.stop_app('guid-1234')
      expect(response.status).to equal(200)
    end
  end
end
