require 'spec_helper'
require 'request_spec_shared_examples'
require 'cloud_controller'
require 'services'
require 'messages/service_broker_update_message'

# The request specs test single actions.
# The lifecycle tests are about combinations of actions
RSpec.describe 'V3 service brokers' do
  describe 'POST /v3/service_brokers' do
    let(:create_request_body) do
      {
          name: 'my-service-broker',
          url: 'http://example.org/my-service-broker-url',
          authentication: {
              type: 'basic',
              credentials: {
                  username: 'admin',
                  password: 'password',
              }
          },
          metadata: {
              labels: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' },
              annotations: { to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value' }
          }
      }
    end

    let(:job_url_for_create) do
      post '/v3/service_brokers', create_request_body.to_json, admin_headers
      expect(last_response).to have_status_code(202)
      last_response['Location']
    end

    describe 'successful creation' do
      before do
        stub_request(:get, 'http://example.org/my-service-broker-url/v2/catalog').
          with(basic_auth: %w(admin password)).
          to_return(status: 200, body: catalog, headers: {})
      end

      it 'creates a service broker' do
        # Request new broker
        get job_url_for_create, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['state']).to eq('PROCESSING')
        broker = parsed_response.dig('links', 'service_brokers', 'href')

        # Check it finishes
        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        get job_url_for_create, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['state']).to eq('COMPLETE')

        # Check it's correct
        get broker, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include(
          'name' => 'my-service-broker',
          'url' => 'http://example.org/my-service-broker-url'
        )
      end
    end

    describe 'failed creation' do
      before do
        stub_request(:get, 'http://example.org/my-service-broker-url/v2/catalog').
          with(basic_auth: %w(admin password)).
          to_return(status: 404)
      end

      it 'creates a service broker in failed state' do
        # Request new broker
        get job_url_for_create, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['state']).to eq('PROCESSING')

        # Check it finishes
        execute_all_jobs(expected_successes: 0, expected_failures: 1)
        get job_url_for_create, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['state']).to eq('FAILED')
      end
    end

    context 'while a broker is being created' do
      describe 'creation during creation' do
        before do
          stub_request(:get, 'http://example.org/my-service-broker-url/v2/catalog').
            with(basic_auth: %w(admin password)).
            to_return(status: 200, body: catalog, headers: {})
        end

        it 'rejects a duplicate name' do
          post '/v3/service_brokers', create_request_body.to_json, admin_headers
          expect(last_response).to have_status_code(202)

          post '/v3/service_brokers', create_request_body.to_json, admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'][0]['detail']).to match('Name must be unique')
        end

        it 'allows a different name' do
          post '/v3/service_brokers', create_request_body.to_json, admin_headers
          expect(last_response).to have_status_code(202)

          other_request_body = create_request_body.merge({ 'name' => 'my-other-broker' }).to_json
          post '/v3/service_brokers', other_request_body, admin_headers
          expect(last_response).to have_status_code(202)
        end
      end

      describe 'deletion during creation' do
        before do
          stub_request(:get, 'http://example.org/my-service-broker-url/v2/catalog').
            with(basic_auth: %w(admin password)).
            to_return(status: 200, body: catalog, headers: {})
        end

        it 'allows deletion during creation' do
          # Request new broker
          get job_url_for_create, {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response['state']).to eq('PROCESSING')
          broker = parsed_response.dig('links', 'service_brokers', 'href')

          # Delete it
          delete broker, {}, admin_headers
          expect(last_response).to have_status_code(202)
          get last_response['Location'], {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response['state']).to eq('PROCESSING')

          # Check it's not there
          execute_all_jobs(expected_successes: 2, expected_failures: 0)
          get broker, {}, admin_headers
          expect(last_response).to have_status_code(404)
        end
      end

      describe 'update during creation' do
        before do
          stub_request(:get, 'http://example.org/my-service-broker-url/v2/catalog').
            with(basic_auth: %w(admin password)).
            to_return(status: 200, body: catalog, headers: {})
        end

        it 'blocks update during creation' do
          # Request new broker
          get job_url_for_create, {}, admin_headers
          expect(last_response).to have_status_code(200)
          expect(parsed_response['state']).to eq('PROCESSING')
          broker = parsed_response.dig('links', 'service_brokers', 'href')

          # Patch should be blocked
          patch broker, create_request_body.to_json, admin_headers
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'][0]['detail']).to match('Cannot update a broker when other operation is already in progress')
        end
      end
    end
  end

  describe 'PATCH /v3/service_brokers/:guid' do
    let(:create_request_body) {
      {
          name: 'old-name',
          url: 'http://example.org/old-broker-url',
          authentication: {
              type: 'basic',
              credentials: {
                  username: 'old-admin',
                  password: 'not-welcome'
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
                  password: 'welcome'
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
          to_return(status: 200, body: catalog, headers: {})

        patch "/v3/service_brokers/#{broker['guid']}", update_request_body.to_json, admin_headers
        expect(last_response).to have_status_code(202)

        job_url = last_response['Location']
        get job_url, {}, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response).to include({
            'state' => 'PROCESSING',
            'operation' => 'service_broker.update',
            'errors' => [],
            'warnings' => []
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
            'url' => 'http://example.org/new-broker-url'
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

  let(:catalog) do
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
              'requires' => %w(volume_mount route_forwarding),
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
    }.to_json
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
      to_return(status: 200, body: catalog, headers: {})

    post '/v3/service_brokers', create_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)

    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    broker_response_from_job(last_response['Location'])
  end
end
