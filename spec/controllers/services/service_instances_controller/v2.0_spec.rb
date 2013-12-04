require 'spec_helper'

describe 'Service Broker API integration', type: :controller do
  describe 'v2.0' do
    before do
      VCAP::CloudController::Controller.any_instance.stub(:in_test_mode?).and_return(false)
    end

    let!(:org) { VCAP::CloudController::Organization.make }
    let!(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:the_space_guid) { space.guid }
    let(:the_org_guid) { org.guid }

    let(:api_header) { 'X-Broker-Api-Version' }
    let(:api_accepted_version) { /^2\.\d+$/ }

    def request_has_version_header(method, url)
      a_request(method, url).
        with { |request| request.headers[api_header].should match(api_accepted_version) }.
        should have_been_made
    end

    describe 'Catalog Management' do
      describe 'fetching the catalog' do
        let(:broker_id_for_service) { 'the-service-id' }
        let(:broker_url) { 'broker-url' }
        let(:broker_name) { 'broker-name' }
        let(:broker_auth_username) { 'username' }
        let(:broker_auth_password) { 'password' }
        let(:request_url) { "http://#{broker_auth_username}:#{broker_auth_password}@#{broker_url}" }
        let(:username_pattern) { '[[:alnum:]-]+' }
        let(:password_pattern) { '[[:alnum:]-]+' }

        before do
          stub_request(:get, request_url + '/v2/catalog').to_return(
            body:
              {
                services: [{
                  id:          "service-guid-here",
                  name:        "MySQL",
                  description: "A MySQL-compatible relational database",
                  bindable:    true,
                  plans:       [{
                    id:          "plan1-guid-here",
                    name:        "small",
                    description: "A small shared database with 100mb storage quota and 10 connections"
                  }, {
                    id:          "plan2-guid-here",
                    name:        "large",
                    description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
                  }]
                }]
              }.to_json)
        end

        shared_examples 'a catalog fetch request' do
          it 'makes request to correct endpoint' do
            a_request(:get, 'http://username:password@broker-url/v2/catalog').
              should have_been_made
          end

          it 'sends basic auth info' do
            a_request(:get, %r(http://#{username_pattern}:#{password_pattern}@broker-url/v2/catalog)).should have_been_made
          end

          it 'uses correct version header' do
            request_has_version_header(:get, 'http://username:password@broker-url/v2/catalog')
          end
        end

        context 'when create-service-broker' do
          before do
            post('/v2/service_brokers',
              { name: broker_name, broker_url: 'http://' + broker_url, auth_username: broker_auth_username, auth_password: broker_auth_password }.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          it 'handles the broker response' do
            expect(last_response.status).to eq(201)
          end
        end

        context 'when update-service-broker' do
          let(:broker) do
            VCAP::CloudController::ServiceBroker.make({
              broker_url:    'http://' + broker_url,
              auth_username: broker_auth_username,
              auth_password: broker_auth_password
            })
          end
          let(:broker_guid) { broker.guid }

          before do
            allow(VCAP::CloudController::ServiceBroker).to receive(:find).and_return(broker)

            put("/v2/service_brokers/#{broker_guid}",
              {}.to_json,
              json_headers(admin_headers))
          end

          it_behaves_like 'a catalog fetch request'

          it 'handles the broker response' do
            expect(last_response.status).to eq(200)
          end
        end
      end
    end

    describe 'Provisioning'
    describe 'Binding'
    describe 'Unbinding'
    describe 'Unprovisioning'
    describe 'Broker Errors'
    describe 'Orphans'

    describe 'a provision request' do
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make(broker_url: the_broker_url) }
      let!(:service) { VCAP::CloudController::Service.make(service_broker: service_broker, url: nil) }
      let!(:plan) { VCAP::CloudController::ServicePlan.make(service: service) }

      let(:the_broker_url) { "http://#{the_broker_domain}" }
      let(:the_broker_domain) { 'the.broker.com' }
      let(:the_service_id) { service.broker_provided_id }
      let(:the_plan_guid) { plan.guid }
      let(:the_plan_id) { plan.broker_provided_id }
      let(:guid_pattern) { '[[:alnum:]-]+' }

      let(:request_to_cc) do
        {
          name:              'test-service',
          space_guid:        the_space_guid,
          service_plan_guid: the_plan_guid
        }
      end

      let(:request_from_cc_to_broker) do
        {
          service_id:        the_service_id,
          plan_id:           the_plan_id,
          organization_guid: the_org_guid,
          space_guid:        the_space_guid,
        }
      end

      it 'sends all required fields' do
        correct_request_to_the_broker = stub_request(:put, %r(#{the_broker_domain}/v2/service_instances/#{guid_pattern})).
          with(body: hash_including(request_from_cc_to_broker)).
          to_return(status: 201, body: '{}')

        post('/v2/service_instances ',
          request_to_cc.to_json,
          json_headers(admin_headers)
        )

        expect(last_response.status).to eq(201)
        expect(correct_request_to_the_broker).to have_been_made
      end


      context 'when the dashboard_url is given' do
        it ' returns a 201 to the user ' do
          dashboard_url = "http://something.com"
          the_request   = stub_request(:put, %r(#{the_broker_domain}/v2/service_instances/#{guid_pattern})).with do |req|
            req.headers[api_header].should match(api_accepted_version)
          end.
            to_return(status: 201, body: %Q({"dashboard_url": #{dashboard_url.inspect}))

          post('/v2/service_instances',
            { name: 'test-service', space_guid: the_space_guid, service_plan_guid: the_plan_guid }.to_json,
            json_headers(admin_headers)
          )

          expect(the_request).to have_been_made
          expect(last_response.status).to eq(201)
          expect(decoded_response['entity']['dashboard_url']).to eq(dashboard_url)
        end
      end

      context 'when the dashboard_url is not given' do
        it 'returns a 201 to the user' do
          the_request = stub_request(:put, %r(#{the_broker_domain}/v2/service_instances/#{guid_pattern})).
            to_return(status: 201, body: '{}')

          post('/v2/service_instances',
            { name: 'test-service', space_guid: the_space_guid, service_plan_guid: the_plan_guid }.to_json,
            json_headers(admin_headers)
          )

          expect(the_request).to have_been_made
          expect(last_response.status).to eq(201)
          expect(decoded_response['entity']['dashboard_url']).to be_nil
        end
      end

      context 'when the broker returns a 409 "conflict"' do
        it 'does not create a new service instance' do
          the_request = stub_request(:put, %r(#{the_broker_domain}/v2/service_instances/#{guid_pattern})).
            to_return(status: 409, body: '{}')

          instance_list = get('/v2/service_instances')

          post('/v2/service_instances',
            { name: 'test-service', space_guid: the_space_guid, service_plan_guid: the_plan_guid }.to_json,
            json_headers(admin_headers)
          )

          expect(the_request).to have_been_made

          expect(last_response.status).to eq(409)
        end
      end
    end
  end
end