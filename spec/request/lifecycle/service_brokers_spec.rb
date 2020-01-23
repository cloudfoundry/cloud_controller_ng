require 'spec_helper'
require 'request_spec_shared_examples'
require 'cloud_controller'
require 'services'
require 'messages/service_broker_update_message'

RSpec.describe 'V3 service brokers' do
  describe 'PATCH /v3/service_brokers/:guid' do
    let(:create_request_body) {
      {
          name: 'old-name',
          url: 'http://example.org/old-broker-url',
          authentication: {
              type: 'basic',
              credentials: {
                  username: 'old-admin',
                  password: 'not-welcome',
              }
          },
          metadata: {
            labels: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' },
            annotations: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' }
          }
      }
    }
    let(:update_request_body) {
      {
          name: 'new-name',
          url: 'http://example.org/new-broker-url',
          authentication: {
              type: 'basic',
              credentials: {
                  username: 'admin',
                  password: 'welcome',
              }
          },
          metadata: {
              labels: { to_update: 'changed-value', to_delete: nil, to_add: 'new-value', 'to.delete/with_prefix' => nil },
              annotations: { to_update: 'changed-value', to_delete: nil, to_add: 'new-value', 'to.delete/with_prefix' => nil }
          }
      }
    }

    let(:broker) { create_service_broker }

    context 'is successful' do
      before do
        stub_request(:get, 'http://example.org/new-broker-url/v2/catalog').
          with(basic_auth: ['admin', 'welcome']).
          to_return(status: 200, body: catalog.to_json, headers: {})

        patch "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
        expect(last_response).to have_status_code(202)

        job_url = last_response['Location']
        get job_url, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include({
            'state' => 'PROCESSING',
            'operation' => 'service_broker.update',
            'errors' => [],
            'warnings' => [],
        })

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        get job_url, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include({
            'state' => 'COMPLETE',
            'operation' => 'service_broker.update',
            'errors' => [],
            'warnings' => [],
        })
      end

      it 'successfully updates the service broker' do
        get "/v3/service_brokers/#{broker['guid']}", {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include({
          'name' => 'new-name',
          'url' => 'http://example.org/new-broker-url',
          'available' => true,
          'status' => 'available',
        })
      end

      it 'adds, removes and updates metadata when the request contains metadata changes' do
        get "/v3/service_brokers/#{broker['guid']}", {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include({
            'metadata' => {
                'labels' => { 'to_update' => 'changed-value', 'to_add' => 'new-value' },
                'annotations' => { 'to_update' => 'changed-value', 'to_add' => 'new-value' }
            }
        })
      end
    end

    it 'fails to update the service broker' do
      stub_request(:get, 'http://example.org/new-broker-url/v2/catalog').
        with(basic_auth: ['admin', 'welcome']).
        to_return(status: 500, body: '', headers: {})

      patch "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
      expect(last_response).to have_status_code(202)

      execute_all_jobs(expected_successes: 0, expected_failures: 1)

      job_url = last_response['Location']
      get job_url, {}, admin_headers
      expect(last_response).to have_status_code(200)
      expect(parsed_response).to include({
          'state' => 'FAILED',
          'operation' => 'service_broker.update',
          'errors' => [include({ 'code' => 10001, 'detail' => include('The service broker returned an invalid response') })],
          'warnings' => []
      })

      get "/v3/service_brokers/#{broker['guid']}", {}, admin_headers
      expect(last_response).to have_status_code(200)
      expect(parsed_response).to include({
          'name' => 'old-name',
          'url' => 'http://example.org/old-broker-url',
          'available' => true,
          'status' => 'available',
          'metadata' => {
              'annotations' => {
                  'to_delete' => 'value',
                  'to_update' => 'value',
                  'to.delete/with_prefix' => 'value'
              },
              'labels' => {
                  'to_delete' => 'value',
                  'to_update' => 'value',
                  'to.delete/with_prefix' => 'value'
              }
          }
      })
    end

    [:delete, :patch].each do |http_method|
      it "errors when a #{http_method} is in progress" do
        method(http_method).call "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
        expect(last_response).to have_status_code(202)

        patch "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
        expect(last_response).to have_status_code(422)
        expect(parsed_response).to include(
          'errors' => [include({
              'code' => 10008,
              'detail' => include('Cannot update a broker when other operation is already in progress')
          })],
        )
        expect(last_response['Location']).to be_nil
      end
    end

    it 'errors when the broker creation is still in progress' do
      post '/v3/service_brokers', create_request_body.to_json, admin_headers
      expect(last_response).to have_status_code(202)

      broker = broker_response_from_job(last_response['Location'])

      patch "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
      expect(last_response).to have_status_code(422)
      expect(parsed_response).to include(
        'errors' => [include({
            'code' => 10008,
            'detail' => include('Cannot update a broker when other operation is already in progress')
        })],
      )
      expect(last_response['Location']).to be_nil
    end
  end

  def catalog
    {
        'services' => [
          {
              'id' => 'catalog1',
              'name' => 'service_name-1',
              'description' => 'some description 1',
              'bindable' => true,
              'plans' => [
                {
                      'id' => 'fake_plan_id-1',
                      'name' => 'plan_name-1',
                      'description' => 'fake_plan_description 1',
                      'schemas' => nil
                  }
              ]
          },
          {
              'id' => 'catalog2',
              'name' => 'route_volume_service_name-2',
              'requires' => ['volume_mount', 'route_forwarding'],
              'description' => 'some description 2',
              'bindable' => true,
              'plans' => [
                {
                    'id' => 'fake_plan_id-2',
                    'name' => 'plan_name-2',
                    'description' => 'fake_plan_description 2',
                    'schemas' => nil
                }
              ]
          },
        ]
    }
  end

  def broker_response_from_job(job_url)
    get job_url, {}, admin_headers
    expect(last_response).to have_status_code(200)

    get parsed_response.dig('links', 'service_brokers', 'href'), {}, admin_headers
    expect(last_response).to have_status_code(200)

    parsed_response
  end

  def create_service_broker
    stub_request(:get, 'http://example.org/old-broker-url/v2/catalog').
      with(basic_auth: ['old-admin', 'not-welcome']).
      to_return(status: 200, body: catalog.to_json, headers: {})

    post '/v3/service_brokers', create_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)

    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    broker_response_from_job(last_response['Location'])
  end
end
