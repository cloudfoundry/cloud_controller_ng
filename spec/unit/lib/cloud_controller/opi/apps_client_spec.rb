require 'spec_helper'
require 'cloud_controller/opi/apps_client'

RSpec.describe(OPI::Client) do
  describe 'can desire an app' do
    subject(:client) { described_class.new(opi_url) }
    let(:opi_url) { 'http://opi.service.cf.internal:8077' }
    let(:img_url) { 'http://example.org/image1234' }

    let(:lrp) {
      double(
        guid: 'guid_1234',
        name: 'dora',
        version: '0.1.0',
        current_droplet: double(docker_receipt_image: img_url, droplet_hash: 'd_haash'),
        command: 'ls -la',
        environment_json: { 'PORT': 8080, 'FOO': 'BAR' },
        desired_instances: 4,
        disk_quota: 100,
        memory: 256,
        file_descriptors: 0xBAAAAAAD,
        uris: [],
        space: double(name: 'name', guid: 'guid'),
        health_check_type: 'http',
        health_check_http_endpoint: '/health',
        health_check_timeout: 1,
        updated_at: Time.at(1529064800.9),
     )
    }

    let(:cfg) { double }

    context 'when request executes successfully' do
      before do
        stub_request(:put, "#{opi_url}/apps/guid_1234-0.1.0").to_return(status: 201)
        allow(VCAP::CloudController::Config).to receive(:config).and_return(cfg)
        allow(cfg).to receive(:get).with(:external_domain).and_return('api.example.com')
        allow(cfg).to receive(:get).with(:external_protocol).and_return('https')
      end

      it 'sends a PUT request' do
        response = client.desire_app(lrp)

        expect(response.status_code).to equal(201)
        expect(WebMock).to have_requested(:put, "#{opi_url}/apps/guid_1234-0.1.0").with(body: {
            process_guid: 'guid_1234-0.1.0',
            docker_image: img_url,
            start_command: 'ls -la',
            environment: {
                'PORT': '8080',
                'FOO': 'BAR',
                'VCAP_APPLICATION': '{"cf_api":"https://api.example.com","limits":{"fds":3131746989,'\
                                      '"mem":256,"disk":100},"application_name":"dora","application_uris":[],'\
                                      '"name":"dora","space_name":"name","space_id":"guid","uris":[],"users":null,'\
                                      '"application_id":"guid_1234","version":"0.1.0","application_version":"0.1.0"}'
            },
            instances: 4,
            droplet_hash: 'd_haash',
            health_check_type: 'http',
            health_check_http_endpoint: '/health',
            health_check_timeout_ms: 1000,
            last_updated: '1529064800.9'
          }.to_json
        )
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
      let(:expected_body) { {
        error: { message: 'reasons for failure' }
      }.to_json}

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
