require 'spec_helper'

describe 'Service Broker API integration', type: :controller do
  describe 'v2.1' do
    before do
      VCAP::CloudController::Controller.any_instance.stub(:in_test_mode?).and_return(false)
    end

    before(:all) { setup_cc }
    let(:space_guid) { @space_guid}
    let(:org_guid) { @org_guid }

    let(:api_header) { 'X-Broker-Api-Version' }
    let(:api_accepted_version) { /^2\.\d+$/ }

    let(:guid_pattern) { '[[:alnum:]-]+' }

    describe 'Binding' do
      let(:broker_response_status) { 200 }
      let(:broker_response_body) do
        {
          credentials: {
            uri:      "mysql://mysqluser:pass@mysqlhost:3306/dbname",
            username: "mysqluser",
            password: "pass",
            host:     "mysqlhost",
            port:     3306,
            database: "dbname"
          }
        }.to_json
      end
      let(:app_guid) { @app_guid }
      let(:service_instance_guid) { @service_instance_guid }
      let(:request_from_cc_to_broker) do
        {
          plan_id: "plan1-guid-here",
          service_id:"service-guid-here",
          app_guid: app_guid
        }
      end


      before do
        setup_broker
        provision_service
        create_app
      end

      after do
        delete_broker
      end

      describe 'service binding request' do
        before do
          stub_request(:put, %r(/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern})).
            to_return(status: broker_response_status, body: broker_response_body)

          post('/v2/service_bindings',
            { app_guid: app_guid, service_instance_guid: service_instance_guid }.to_json,
            json_headers(admin_headers))
        end

        it 'uses the correct version header' do
          request_has_version_header(:put, %r(/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$))
        end

        it 'sends the app_guid as part of the request' do
          a_request(:put, %r(broker-url/v2/service_instances/#{service_instance_guid}/service_bindings/#{guid_pattern}$)).
            with(body: hash_including(request_from_cc_to_broker)).
            should have_been_made
        end
      end
    end
  end
end
