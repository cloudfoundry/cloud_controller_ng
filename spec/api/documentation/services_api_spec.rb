require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Services', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
  let!(:service) { VCAP::CloudController::Service.make(service_broker: service_broker) }
  let(:guid) { service.guid }

  authenticated_request

  describe 'Standard endpoints' do
    field :guid, 'The guid of the service', required: false
    field :label, 'The name of the service', required: true, example_values: ['SomeMysqlService']
    field :description, 'A short blurb describing the service', required: true, example_values: ['Mysql stores things for you']

    field :long_description,
      'A longer description of the service',
      required: false,
      deprecated: true,
      example_values: ['Mysql is a database. It stores things. Use it in your apps...'], default: nil

    field :info_url, 'A url that points to an info page for the service', required: false, deprecated: true, example_values: ['http://info.somemysqlservice.com'], default: nil

    field :documentation_url,
      'A url that points to a documentation page for the service',
      required: false,
      deprecated: true,
      example_values: ['http://docs.somemysqlservice.com'],
      default: nil

    field :timeout, 'A timeout used by the v1 service gateway client', required: false, deprecated: true, default: nil
    field :active, 'A boolean describing that the service can be provisioned by users', required: false, default: false
    field :bindable, 'A boolean describing that the service can be bound to applications', required: false, default: true
    field :extra, 'A JSON field with extra data pertaining to the service', required: false, default: nil, example_values: ['{"providerDisplayName": "MyServiceProvider"}']
    field :unique_id, 'A guid that identifies the service with the broker (not the same as the guid above)', required: false, default: nil
    field :tags, 'A list of tags for the service', required: false, default: [], example_values: ['database', 'mysql']
    field :requires, 'A list of dependencies for services', required: false, default: [], example_values: ['syslog_drain']

    field :provider, 'The name of the service provider (used only by v1 service gateways)', required: true, deprecated: true, example_values: ['MySql Provider']
    field :version, 'The version of the service (used only by v1 service gateways)', required: true, deprecated: true, example_values: ['2.0']
    field :url, 'The url of ther service provider (used only by v1 service gateways)', required: true, deprecated: true, example_values: ['http://myql.provider.com']
    field :service_broker_guid, 'The guid of the v2 service broker associated with the service', required: false, deprecated: false
    field :plan_updateable, 'A boolean describing that an instance of this service can be updated to a different plan', default: false

    standard_model_list(:services, VCAP::CloudController::ServicesController)
    standard_model_get(:services)

    delete '/v2/services/:guid' do
      request_parameter :async, "Will run the delete request in a background job. Recommended: 'true'."
      request_parameter :purge, 'Recursively remove a service and child objects from Cloud Foundry database without making requests to a service broker'

      example 'Delete a Particular Service' do
        client.delete "/v2/services/#{guid}", {}, headers
        expect(status).to eq 204
      end
    end

    post '/v2/services', deprecated: true do
      example 'Creating a Service (deprecated)' do
        client.post '/v2/services', fields_json, headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :services
      end
    end

    put '/v2/services' do
      example 'Updating a Service (deprecated)' do
        client.put "/v2/services/#{guid}", fields_json, headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :services
      end
    end
  end

  describe 'Nested endpoints' do
    field :guid, 'The guid of the Service.', required: true

    describe 'Service Plans' do
      before do
        VCAP::CloudController::ServicePlan.make(service: service)
      end

      standard_model_list :service_plan, VCAP::CloudController::ServicePlansController, outer_model: :service
    end
  end
end
