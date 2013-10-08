require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Service Bindings", :type => :api do
  let(:application) { VCAP::CloudController::App.make }
  let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: application.space) }
  let(:org_manager) { make_manager_for_org application.space.organization, application.space }

  let(:admin_auth_header) { headers_for(org_manager, :admin_scope => false)["HTTP_AUTHORIZATION"] }
  authenticated_request

  field :app_guid, "The guid for the app to bind to", required: true
  field :service_instance_guid, "The guid for the service_instance to to use", required: true
  field :credentials, "Credentials used to bind to the service instance (e.g. port, username, password)"
  field :binding_options, "(Unused)"
  field :gateway_data, "(Unused)"
  field :gateway_name, "Identifier for the service gateway"

  context "as an admin" do
    before do
      VCAP::CloudController::ServiceBinding.make
      VCAP::Services::Api::ServiceGatewayClientFake.any_instance.stub(:syslog_drain_url).and_return(nil)
      VCAP::Services::Api::ServiceGatewayClientFake.any_instance.stub(:unbind)
    end

    let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
    let(:guid) { VCAP::CloudController::ServiceBinding.first.guid }

    standard_parameters
    standard_model_object :service_binding
  end

  context "as an org_manager" do
    before do
      VCAP::Services::Api::ServiceGatewayClientFake.any_instance.stub(:syslog_drain_url).and_return(nil)
    end

    post "/v2/service_bindings" do
      example "Binding a service to an app" do

        explanation <<EOD
POST with the app guid and service instance guid to bind the service instance to the app.
EOD

        client.post "/v2/service_bindings", Yajl::Encoder.encode(app_guid: application.guid, service_instance_guid: service_instance.guid), headers

        status.should == 201
        standard_entity_response parsed_response, :service_binding, { app_guid: application.guid, service_instance_guid: service_instance.guid}
      end
    end
  end
end
