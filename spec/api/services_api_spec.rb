require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Services", type: :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  field :guid, "The guid of the service", required: false
  field :label, "The name of the service", required: true, example_values: ["SomeMysqlService"]
  field :description, "A short blurb describing the service", required: true, example_values: ["Mysql stores things for you"]
  field :long_description, "A longer description of the service", required: false, example_values: ["Mysql is a database. It stores things. Use it in your apps..."], default: nil
  field :info_url, "A url that points to an info page for the service", required: false, example_values: ["http://info.somemysqlservice.com"], default: nil
  field :documentation_url, "A url that points to a documentation page for the service", required: false, example_values: ["http://docs.somemysqlservice.com"], default: nil

  field :timeout, "A timeout used by the v1 service gateway client", required: false, deprecated: true, default: nil
  field :active, "A boolean describing that the service can be provisioned by users", required: false, default: false
  field :bindable, "A boolean describing that the service can be bound to applications", required: false, default: true
  field :extra, "A JSON field with extra data pertaining to the service", required: false, default: nil, example_values: ['{"providerDisplayName": "MyServiceProvider"}']
  field :unique_id, "A guid that identifies the service with the broker (not the same as the guid above)", required: false, default: nil
  field :tags, "A list of tags for the service", required: false, default: [], example_values: ['database', 'mysql']
  field :requires, "A list of dependencies for services", required: false, default: [], example_values: ["syslog_drain"]

  field :provider, "The name of the service provider (used only by v1 service gateways)", required: true, deprecated: true, example_values: ["MySql Provider"]
  field :version, "The version of the service (used only by v1 service gateways)", required: true, deprecated: true, example_values: ["2.0"]
  field :url, "The url of ther service provider (used only by v1 service gateways)", required: true, deprecated: true, example_values: ["http://myql.provider.com"]

  before { VCAP::CloudController::Service.make }
  let(:guid) { VCAP::CloudController::Service.first.guid }

  standard_model_list(:services, VCAP::CloudController::ServicesController)
  standard_model_get(:services)
  standard_model_delete(:services)

  post "/v2/services", deprecated: true do
    example "Creating a service (deprecated)" do
      client.post "/v2/services", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :services
    end
  end

  put "/v2/services" do
    example "Updating a service (deprecated)" do
      client.put "/v2/services/#{guid}", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :services
    end
  end
end
