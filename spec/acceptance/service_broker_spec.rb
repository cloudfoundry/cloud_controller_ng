require 'spec_helper'

describe 'Service Broker' do
  include VCAP::CloudController::BrokerApiHelper

  let(:catalog_with_no_plans) {{
    services:
      [{
         id:          "service-guid-here",
         name:        service_name,
         description: "A MySQL-compatible relational database",
         bindable:    true,
         plans:       [{}]
       }]
  }}

  let(:catalog_with_small_plan) {{
    services:
      [{
         id:          "service-guid-here",
         name:        service_name,
         description: "A MySQL-compatible relational database",
         bindable:    true,
         plans:       [{
                         id:          "plan1-guid-here",
                         name:        "small",
                         description: "A small shared database with 100mb storage quota and 10 connections"
                       }]
       }]
  }}

  let(:catalog_with_large_plan) {{
    services:
      [{
         id:          "service-guid-here",
         name:        service_name,
         description: "A MySQL-compatible relational database",
         bindable:    true,
         plans:       [{
                         id:          "plan2-guid-here",
                         name:        "large",
                         description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
                       }]
       }]
  }}

  let(:catalog_with_two_plans)  {{
    services:
      [{
          id:          "service-guid-here",
          name:        service_name,
          description: "A MySQL-compatible relational database",
          bindable:    true,
          plans:
            [{
               id:          "plan1-guid-here",
               name:        "small",
               description: "A small shared database with 100mb storage quota and 10 connections"
             }, {
               id:          "plan2-guid-here",
               name:        "large",
               description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
             }]
      }]
  }}

  before(:each) { setup_cc }

  def build_service(attrs={})
    @index ||= 0
    @index += 1
    {
      id: SecureRandom.uuid,
      name: "service-#{@index}",
      description: "A service, duh!",
      bindable: true,
      plans: [{
                id: "plan-#{@index}",
                name: "plan-#{@index}",
                description: "A plan, duh!"
              }]
    }.merge(attrs)
  end

  describe 'adding a service broker' do
    context 'when a service has no plans' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id: '12345',
            name: 'MySQL',
            description: 'A MySQL service, duh!',
            bindable: true,
            plans: []
          }]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql("Service broker catalog is invalid: \nService MySQL\n  At least one plan is required\n")
      end
    end

    context 'when there are multiple validation problems in the catalog' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id: 12345,
            name: "service-1",
            description: "A service, duh!",
            bindable: true,
            plans: [{
              id: "plan-1",
              name: "small",
              description: "A small shared database with 100mb storage quota and 10 connections"
            }, {
              id: "plan-2",
              name: "large",
              description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
            }]
          },
            {
              id: '67890',
              name: "service-2",
              description: "Another service, duh!",
              bindable: true,
              plans: [{
                id: "plan-b",
                name: "small",
                description: "A small shared database with 100mb storage quota and 10 connections"
              }, {
                id: "plan-b",
                name: "large",
                description: ""
              }]
            },
            {
              id: '67890',
              name: "service-3",
              description: "Yet another service, duh!",
              bindable: true,
              dashboard_client: {
                id: 'client-1'
              },
              plans: [{
                id: 123,
                name: "tiny",
                description: "A small shared database with 100mb storage quota and 10 connections"
              }, {
                id: '456',
                name: "tiny",
                description: "A large dedicated database with 10GB storage quota, 512MB of RAM, and 100 connections"
              }]
            },
            {
              id: '987654',
              name: "service-4",
              description: "Yet another service, duh!",
              bindable: true,
              dashboard_client: {
                id: 'client-1',
                secret: 'no-one-knows',
                redirect_uri: 'http://example.com/client-1'
              },
              plans: []
            }
          ]
        })
      end

      it 'notifies the operator of the problem' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        expect(last_response.status).to eql(502)
        expect(decoded_response['code']).to eql(270012)
        expect(decoded_response['description']).to eql(
          "Service broker catalog is invalid: \n" +
            "Service ids must be unique\n" +
            "Service dashboard_client id must be unique\n" +
            "Service service-1\n" +
            "  Service id must be a string, but has value 12345\n" +
            "Service service-2\n" +
            "  Plan ids must be unique\n" +
            "  Plan large\n" +
            "    Plan description is required\n" +
            "Service service-3\n" +
            "  Service dashboard client secret is required\n" +
            "  Service dashboard client redirect_uri is required\n" +
            "  Plan names must be unique within a service\n" +
            "  Plan tiny\n" +
            "    Plan id must be a string, but has value 123\n" +
            "Service service-4\n" +
            "  At least one plan is required\n"
        )
      end
    end

    context 'when a plan has a free field in the catalog' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id: '12345',
            name: 'service-1',
            description: 'A service, duh!',
            bindable: true,
            plans: [{
              id: 'plan-1',
              name: 'not-free-plan',
              description: 'A not free plan',
              free: false
            }, {
              id: 'plan-2',
              name: 'free-plan',
              description: 'A free plan',
              free: true
            }]
          }]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))
      end

      it 'sets the cc plan free field' do
        get('/v2/service_plans', {}.to_json, json_headers(admin_headers))

        resources     = JSON.parse(last_response.body)['resources']
        not_free_plan = resources.find { |plan| plan['entity']['name'] == 'not-free-plan' }
        free_plan     = resources.find { |plan| plan['entity']['name'] == 'free-plan' }

        expect(free_plan['entity']['free']).to be true
        expect(not_free_plan['entity']['free']).to be false
      end
    end

    context 'when the CC dashboard_client feature is disabled and the catalog requests a client' do
      let(:service) { build_service(dashboard_client: { id: 'client-id', secret: 'shhhhh', redirect_uri: 'http://example.com/client-id' })}

      before do
        allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
        allow(VCAP::CloudController::Config.config).to receive(:[]).with(:uaa_client_name).and_return nil
        allow(VCAP::CloudController::Config.config).to receive(:[]).with(:uaa_client_secret).and_return nil

        stub_catalog_fetch(200, services: [service])
      end

      it 'returns a warning' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
        expect(warning).to eq('Warning: This broker includes configuration for a dashboard client. Auto-creation of OAuth2 clients has been disabled in this Cloud Foundry instance. The broker catalog has been updated but its dashboard client configuration will be ignored.')
      end

      it 'does not create any dashboard clients' do
        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        expect(VCAP::CloudController::ServiceDashboardClient.count).to eq(0)
      end

    end
  end

  describe 'updating a service broker' do
    context 'when the dashboard_client values for a service have changed' do
      let(:service_1) { build_service(dashboard_client: { id: 'client-1', secret: 'shhhhh', redirect_uri: 'http://example.com/client-1' }) }
      let(:service_2) { build_service(dashboard_client: { id: 'client-2', secret: 'sekret', redirect_uri: 'http://example.com/client-2' }) }
      let(:service_3) { build_service(dashboard_client: { id: 'client-3', secret: 'unguessable', redirect_uri: 'http://example.com/client-3' }) }
      let(:service_4) { build_service }
      let(:service_5) { build_service(dashboard_client: { id: 'client-5', secret: 'secret5', redirect_uri: 'http://example.com/client-5' }) }
      let(:service_6) { build_service(dashboard_client: { id: 'client-6', secret: 'secret6', redirect_uri: 'http://example.com/client-6' }) }

      before do
        # set up a fake broker catalog that includes dashboard_client for services
        stub_catalog_fetch(200, services: [service_1, service_2, service_3, service_4, service_5, service_6])
        UAARequests.stub_all
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/.*}).to_return(status: 404)

        # add that broker to the CC
        post('/v2/service_brokers',
          {
            name: 'broker_name',
            broker_url: stubbed_broker_url,
            auth_username: stubbed_broker_username,
            auth_password: stubbed_broker_password
          }.to_json,
          json_headers(admin_headers)
        )
        expect(last_response).to have_status_code(201)
        @service_broker_guid = decoded_response.fetch('metadata').fetch('guid')

        WebMock.reset!

        UAARequests.stub_all
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/.*}).to_return(status: 404)
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-1}).to_return(
          body:    { client_id: 'client-1' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-2}).to_return(
          body:    { client_id: 'client-2' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-3}).to_return(
          body:    { client_id: 'client-3' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-5}).to_return(
          body:    { client_id: 'client-5' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-6}).to_return(
          body:    { client_id: 'client-6' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })

        # delete client
        service_1.delete(:dashboard_client)
        # change client id - should result in a delete and a create
        service_2[:dashboard_client][:id] = 'different-client'
        # change client secret - should post to /clients/<client-id>/secret
        service_3[:dashboard_client][:secret] = 'SUPERsecret'
        # add client
        service_4[:dashboard_client] = {id: 'client-4', secret: '1337', redirect_uri: 'http://example.com/client-4'}
        # change property other than ID or secret
        service_5[:dashboard_client][:redirect_uri] = 'http://nowhere.net'

        stub_catalog_fetch(200, services: [service_1, service_2, service_3, service_4, service_5, service_6])

        stub_request(:post, %r{http://localhost:8080/uaa/oauth/clients/tx/modify}).
          to_return(
          status: 200,
          headers: {'content-type' => 'application/json'},
          body: ""
        )
      end

      it 'sends the correct batch request to create/update/delete clients' do
        put("/v2/service_brokers/#{@service_broker_guid}", '{}', json_headers(admin_headers))

        expect(last_response).to have_status_code(200)

        expected_client_modifications = [
          { # client deleted
            'client_id'              => 'client-1',
            'client_secret'          => nil,
            'redirect_uri'           => nil,
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'delete'
          },
          { # client id renamed to 'different-client'
            'client_id'              => 'client-2',
            'client_secret'          => nil,
            'redirect_uri'           => nil,
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'delete'
          },
          { # client id renamed from 'client-2'
            'client_id'              => 'different-client',
            'client_secret'          => service_2[:dashboard_client][:secret],
            'redirect_uri'           => service_2[:dashboard_client][:redirect_uri],
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'add'
          },
          { # client secret updated
            'client_id'              => service_3[:dashboard_client][:id],
            'client_secret'          => 'SUPERsecret',
            'redirect_uri'           => service_3[:dashboard_client][:redirect_uri],
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'update,secret'
          },
          { # newly added client
            'client_id'              => service_4[:dashboard_client][:id],
            'client_secret'          => service_4[:dashboard_client][:secret],
            'redirect_uri'           => service_4[:dashboard_client][:redirect_uri],
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'add'
          },
          { # client redirect_uri updated
            'client_id'              => service_5[:dashboard_client][:id],
            'client_secret'          => service_5[:dashboard_client][:secret],
            'redirect_uri'           => 'http://nowhere.net',
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'update,secret'
          },
          { # no change
            'client_id'              => service_6[:dashboard_client][:id],
            'client_secret'          => service_6[:dashboard_client][:secret],
            'redirect_uri'           => service_6[:dashboard_client][:redirect_uri],
            'scope'                  => ['openid', 'cloud_controller_service_permissions.read'],
            'authorized_grant_types' => ['authorization_code'],
            'action'                 => 'update,secret'
          }
        ]

        expect(a_request(:post, 'http://localhost:8080/uaa/oauth/clients/tx/modify').with do |req|
          client_modifications = JSON.parse(req.body)
          expect(client_modifications).to match_array(expected_client_modifications)
        end).to have_been_made

      end

      it 'can update the service broker name' do
        put("/v2/service_brokers/#{@service_broker_guid}", "{\"name\":\"new_broker_name\"}",
            json_headers(admin_headers))

        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body['entity']['name']).to eq("new_broker_name")
      end
    end

    context 'when the free field for a plan has changed' do
      before do
        stub_catalog_fetch(200, {
          services: [{
            id: '12345',
            name: 'service-1',
            description: 'A service, duh!',
            bindable: true,
            plans: [{
              id: 'plan-1',
              name: 'not-free-plan',
              description: 'A not free plan',
              free: false
            }, {
              id: 'plan-2',
              name: 'free-plan',
              description: 'A free plan',
              free: true
            }]
          }]
        })

        post('/v2/service_brokers', {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))

        guid = VCAP::CloudController::ServiceBroker.first.guid

        stub_catalog_fetch(200, {
          services: [{
            id: '12345',
            name: 'service-1',
            description: 'A service, duh!',
            bindable: true,
            plans: [{
              id: 'plan-1',
              name: 'not-free-plan',
              description: 'A not free plan',
              free: true
            }, {
              id: 'plan-2',
              name: 'free-plan',
              description: 'A free plan',
              free: false
            }]
          }]
        })

        put("/v2/service_brokers/#{guid}", {
          name: 'some-guid',
          broker_url: 'http://broker-url',
          auth_username: 'username',
          auth_password: 'password'
        }.to_json, json_headers(admin_headers))
      end

      it 'sets the cc plan free field' do
        get('/v2/service_plans', {}.to_json, json_headers(admin_headers))

        resources               = JSON.parse(last_response.body)['resources']
        no_longer_not_free_plan = resources.find { |plan| plan['entity']['name'] == 'not-free-plan' }
        no_longer_free_plan     = resources.find { |plan| plan['entity']['name'] == 'free-plan' }

        expect(no_longer_free_plan['entity']['free']).to be false
        expect(no_longer_not_free_plan['entity']['free']).to be true
      end
    end

    context 'when a service plan disappears from the catalog' do
      before do
        setup_broker(catalog_with_two_plans)
      end

      context 'when it has an existing instance' do
        before do
          provision_service
        end

        it 'the plan should become inactive' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          expect(VCAP::CloudController::ServicePlan.find(unique_id: 'plan1-guid-here')[:active]).to be false
        end

        it 'returns a warning to the operator' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])

# rubocop:disable LineLength
          expect(warning).to eq(<<HEREDOC)
Warning: Service plans are missing from the broker's catalog (http://#{stubbed_broker_host}/v2/catalog) but can not be removed from Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if these operations fail contact your broker provider.
#{service_name}
  small
HEREDOC
# rubocop:enable LineLength
        end
      end

      context 'when it has no existing instance' do

        it 'the plan should become inactive' do
          update_broker(catalog_with_large_plan)
          expect(last_response).to have_status_code(200)

          get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(1)
        end
      end

      context 'when the service is updated to have no plans' do

        it 'returns an error and does not update the broker' do
          update_broker(catalog_with_no_plans)
          expect(last_response).to have_status_code(502)

          get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
          expect(last_response).to have_status_code(200)

          parsed_body = JSON.parse(last_response.body)
          expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(2)
        end
      end
    end
  end

  describe 'deleting a service broker' do
    context 'when broker has dashboard clients' do
      let(:service_1) { build_service(dashboard_client: { id: 'client-1', secret: 'shhhhh', redirect_uri: service_1 = 'http://example.com/client-1' }) }
      let(:service_2) { build_service(dashboard_client: { id: 'client-2', secret: 'sekret', redirect_uri: 'http://example.com/client-2' }) }
      let(:service_3) { build_service }

      before do

        # set up a fake broker catalog that includes dashboard_client for services
        stub_catalog_fetch(200, services: [service_1, service_2, service_3])
        UAARequests.stub_all
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/.*}).to_return(status: 404)

        # add that broker to the CC
        post('/v2/service_brokers',
             {
               name: 'broker_name',
               broker_url: stubbed_broker_url,
               auth_username: stubbed_broker_username,
               auth_password: stubbed_broker_password
             }.to_json,
             json_headers(admin_headers)
        )
        expect(last_response).to have_status_code(201)
        @service_broker_guid = decoded_response.fetch('metadata').fetch('guid')

        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-1}).to_return(
          body:    { client_id: 'client-1' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })
        stub_request(:get, %r{http://localhost:8080/uaa/oauth/clients/client-2}).to_return(
          body:    { client_id: 'client-2' }.to_json,
          status:  200,
          headers: { 'content-type' => 'application/json' })

        stub_request(:post, %r{http://localhost:8080/uaa/oauth/clients/tx/modify}).
          to_return(
          status: 200,
          headers: {'content-type' => 'application/json'},
          body: ""
        )
      end

      it 'deletes the dashboard clients from UAA' do
        delete("/v2/service_brokers/#{@service_broker_guid}", '', json_headers(admin_headers))
        expect(last_response).to have_status_code(204)

        expected_json_body = [
          {
            client_id:              service_1[:dashboard_client][:id],
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  ['openid', 'cloud_controller_service_permissions.read'],
            authorized_grant_types: ['authorization_code'],
            action:                 'delete'
          },
          {
            client_id:              service_2[:dashboard_client][:id],
            client_secret:          nil,
            redirect_uri:           nil,
            scope:                  ['openid', 'cloud_controller_service_permissions.read'],
            authorized_grant_types: ['authorization_code'],
            action:                 'delete'
          }
        ].to_json

        expect(a_request(:post, 'http://localhost:8080/uaa/oauth/clients/tx/modify').with(
          body:  expected_json_body
        )).to have_been_made
      end
    end

    context 'when a service instance exists' do
      before do
        setup_broker(catalog_with_small_plan)
        provision_service
      end

      after do
        deprovision_service
        delete_broker
      end

      it 'does not delete the broker', isolation: :truncation do # Can't use transactions for isolation because we're
                                                                 # testing a rollback
        delete_broker
        expect(last_response).to have_status_code(400)

        get('/v2/services?inline-relations-depth=1', '{}', json_headers(admin_headers))
        expect(last_response).to have_status_code(200)

        parsed_body = JSON.parse(last_response.body)
        expect(parsed_body['resources'].first['entity']['label']).to eq(service_name)
        expect(parsed_body['resources'].first['entity']['service_plans'].length).to eq(1)
      end
    end
  end
end
