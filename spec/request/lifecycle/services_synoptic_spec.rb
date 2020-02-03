require 'spec_helper'
require 'request_spec_shared_examples'
require 'cloud_controller'
require 'services'
require 'messages/service_broker_update_message'

# This lifecycle test aims to use different v3 service endpoints together
RSpec.describe 'V3 services synoptic' do
  before do
    stub_request(:get, 'http://example.org/amazing-service-broker/v2/catalog').
        with(basic_auth: %w(admin password)).
        to_return(status: 200, body: catalog, headers: {})
  end

  it 'works end to end' do
    post '/v3/service_brokers', create_service_broker_request_body.to_json, admin_headers
    expect(last_response).to have_status_code(202)
    execute_all_jobs(expected_successes: 1, expected_failures: 0)

    get '/v3/service_offerings', {}, admin_headers
    expect(last_response).to have_status_code(200)
    expect(parsed_response['resources'][0]).to include(
        'name' => 'service_name-1'
    )
    expect(parsed_response['resources'][1]).to include(
        'name' => 'route_volume_service_name-20'
    )

    # TODO: enable service access once those endpoints are written
    # TODO: view service plans those endpoints are written
    # TODO: create a service instance once those endpoints are written
  end

  let(:create_service_broker_request_body) do
    {
        name: 'amazing-service-broker',
        url: 'http://example.org/amazing-service-broker',
        authentication: {
            type: 'basic',
            credentials: {
                username: 'admin',
                password: 'password',
            }
        },
        metadata: {
            labels: {to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value'},
            annotations: {to_update: 'value', to_delete: 'value', 'to.delete/with_prefix' => 'value'}
        }
    }
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
    }.to_json
  end
end
