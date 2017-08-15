require 'spec_helper'

RSpec.describe 'ServiceBindings' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/service_bindings' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:process1) { VCAP::CloudController::ProcessModelFactory.make(diego: false, space: space) }
    let(:process2) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let!(:service_binding1) do
      VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: process1.app, credentials: { secret: 'key' })
    end
    let!(:service_binding2) do
      VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: process2.app, credentials: { top: 'secret' })
    end
    let!(:service_binding3) { VCAP::CloudController::ServiceBinding.make }

    it 'lists service bindings' do
      get '/v2/service_bindings', nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 2,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'metadata' => {
                'guid' => service_binding1.guid,
                'url' => "/v2/service_bindings/#{service_binding1.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'app_guid' => process1.guid,
                'service_instance_guid' => service_instance.guid,
                'credentials' => { 'secret' => 'key' },
                'binding_options' => {},
                'gateway_data' => nil,
                'gateway_name' => '',
                'syslog_drain_url' => nil,
                'volume_mounts' => [],
                'app_url' => "/v2/apps/#{process1.guid}",
                'service_instance_url' => "/v2/service_instances/#{service_instance.guid}"
              }
            },
            {
              'metadata' => {
                'guid' => service_binding2.guid,
                'url' => "/v2/service_bindings/#{service_binding2.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'app_guid' => process2.guid,
                'service_instance_guid' => service_instance.guid,
                'credentials' => { 'top' => 'secret' },
                'binding_options' => {},
                'gateway_data' => nil,
                'gateway_name' => '',
                'syslog_drain_url' => nil,
                'volume_mounts' => [],
                'app_url' => "/v2/apps/#{process2.guid}",
                'service_instance_url' => "/v2/service_instances/#{service_instance.guid}"
              }
            }
          ]
        }
      )
    end

    it 'does not list service bindings without web processes' do
      non_web_process = VCAP::CloudController::ProcessModelFactory.make(space: space, type: 'non-web')
      non_displayed_binding = VCAP::CloudController::ServiceBinding.make(app: non_web_process.app, service_instance: service_instance)

      get '/v2/service_bindings', nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['resources'].map { |r| r['metadata']['guid'] }).to_not include(non_displayed_binding.guid)
    end

    describe 'inline-relations-depth=1' do
      let(:service_binding2) { nil }

      it 'lists service bindings and their relations' do
        get '/v2/service_bindings?inline-relations-depth=1', nil, headers_for(user)
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages' => 1,
            'prev_url' => nil,
            'next_url' => nil,
            'resources' => [
              {
                'metadata' => {
                  'guid' => service_binding1.guid,
                  'url' => "/v2/service_bindings/#{service_binding1.guid}",
                  'created_at' => iso8601,
                  'updated_at' => iso8601
                },
                'entity' => {
                  'app_guid' => process1.guid,
                  'service_instance_guid' => service_instance.guid,
                  'credentials' => { 'secret' => 'key' },
                  'binding_options' => {},
                  'gateway_data' => nil,
                  'gateway_name' => '',
                  'syslog_drain_url' => nil,
                  'volume_mounts' => [],
                  'app_url' => "/v2/apps/#{process1.guid}",
                  'app' => {
                    'metadata' => {
                      'guid' => process1.guid,
                      'url' => "/v2/apps/#{process1.guid}",
                      'created_at' => iso8601,
                      'updated_at' => iso8601
                    },
                    'entity' => {
                      'name' => process1.name,
                      'production' => false,
                      'space_guid' => space.guid,
                      'stack_guid' => process1.stack.guid,
                      'buildpack' => nil,
                      'detected_buildpack' => nil,
                      'detected_buildpack_guid' => nil,
                      'environment_json' => nil,
                      'memory' => 1024,
                      'instances' => 1,
                      'disk_quota' => 1024,
                      'state' => 'STOPPED',
                      'version' => process1.version,
                      'command' => nil,
                      'console' => false,
                      'debug' => nil,
                      'staging_task_id' => process1.latest_build.guid,
                      'package_state' => 'STAGED',
                      'health_check_type' => 'port',
                      'health_check_timeout' => nil,
                      'health_check_http_endpoint' => nil,
                      'staging_failed_reason' => nil,
                      'staging_failed_description' => nil,
                      'diego' => false,
                      'docker_image' => nil,
                      'docker_credentials' => {
                        'username' => nil,
                        'password' => nil,
                      },
                      'package_updated_at' => iso8601,
                      'detected_start_command' => '',
                      'enable_ssh' => true,
                      'ports' => nil,
                      'space_url' => "/v2/spaces/#{space.guid}",
                      'stack_url' => "/v2/stacks/#{process1.stack.guid}",
                      'routes_url' => "/v2/apps/#{process1.guid}/routes",
                      'events_url' => "/v2/apps/#{process1.guid}/events",
                      'service_bindings_url' => "/v2/apps/#{process1.guid}/service_bindings",
                      'route_mappings_url' => "/v2/apps/#{process1.guid}/route_mappings"
                    }
                  },
                  'service_instance_url' => "/v2/service_instances/#{service_instance.guid}",
                  'service_instance' => {
                    'metadata' => {
                      'guid' => service_instance.guid,
                      'url' => "/v2/service_instances/#{service_instance.guid}",
                      'created_at' => iso8601,
                      'updated_at' => iso8601
                    },
                    'entity' => {
                      'name' => service_instance.name,
                      'credentials' => service_instance.credentials,
                      'service_plan_guid' => service_instance.service_plan.guid,
                      'service_guid' => service_instance.service.guid,
                      'space_guid' => space.guid,
                      'gateway_data' => nil,
                      'dashboard_url' => nil,
                      'type' => 'managed_service_instance',
                      'last_operation' => nil,
                      'tags' => [],
                      'space_url' => "/v2/spaces/#{space.guid}",
                      'service_url' => "/v2/services/#{service_instance.service.guid}",
                      'service_plan_url' => "/v2/service_plans/#{service_instance.service_plan.guid}",
                      'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                      'service_keys_url' => "/v2/service_instances/#{service_instance.guid}/service_keys",
                      'routes_url' => "/v2/service_instances/#{service_instance.guid}/routes"
                    }
                  }
                }
              }
            ]
          }
        )
      end
    end

    describe 'filtering' do
      it 'filters by app_guid' do
        get "/v2/service_bindings?q=app_guid:#{process2.guid}", nil, headers_for(user)
        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['total_results']).to eq(1)
        expect(parsed_response['resources'][0]['metadata']['guid']).to eq(service_binding2.guid)
      end

      it 'filters by service_instance_guid' do
        filtered_service_instance = VCAP::CloudController::ManagedServiceInstance.make(space: space)
        filtered_service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: filtered_service_instance, app: process1.app)

        get "/v2/service_bindings?q=service_instance_guid:#{filtered_service_instance.guid}", nil, headers_for(user)
        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['total_results']).to eq(1)
        expect(parsed_response['resources'][0]['metadata']['guid']).to eq(filtered_service_binding.guid)
      end
    end
  end

  describe 'GET /v2/service_bindings/:guid' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:process1) { VCAP::CloudController::ProcessModelFactory.make(space: space) }
    let!(:service_binding1) do
      VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: process1.app, credentials: { secret: 'key' })
    end

    it 'displays the service binding' do
      get "/v2/service_bindings/#{service_binding1.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid' => service_binding1.guid,
            'url' => "/v2/service_bindings/#{service_binding1.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'app_guid' => process1.guid,
            'service_instance_guid' => service_instance.guid,
            'credentials' => { 'secret' => 'key' },
            'binding_options' => {},
            'gateway_data' => nil,
            'gateway_name' => '',
            'syslog_drain_url' => nil,
            'volume_mounts' => [],
            'app_url' => "/v2/apps/#{process1.guid}",
            'service_instance_url' => "/v2/service_instances/#{service_instance.guid}"
          }
        }
      )
    end

    it 'does not display service bindings without a web process' do
      non_web_process = VCAP::CloudController::ProcessModelFactory.make(space: space, type: 'non-web')
      non_displayed_binding = VCAP::CloudController::ServiceBinding.make(app: non_web_process.app, service_instance: service_instance)

      get "/v2/service_bindings/#{non_displayed_binding.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /v2/service_bindings' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:process) { VCAP::CloudController::ProcessModelFactory.make(space: space) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        fb = FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
        fb.credentials = { 'username' => 'managed_username' }
        fb.syslog_drain_url = 'syslog://mydrain.example.com'
        fb.volume_mounts = [{ 'container_dir' => 'mount', 'private' => 'secret-thing' }]
        fb
      end
    end

    it 'creates a service binding' do
      req_body = {
        service_instance_guid: service_instance.guid,
        app_guid: process.guid,
        parameters: { hello: 'mr_broker' }
      }.to_json

      post '/v2/service_bindings', req_body, headers_for(user)
      expect(last_response.status).to eq(201)

      service_binding = VCAP::CloudController::ServiceBinding.last

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid' => service_binding.guid,
            'url' => "/v2/service_bindings/#{service_binding.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'app_guid' => process.guid,
            'service_instance_guid' => service_instance.guid,
            'credentials' => { 'username' => 'managed_username' },
            'binding_options' => {},
            'gateway_data' => nil,
            'gateway_name' => '',
            'syslog_drain_url' => 'syslog://mydrain.example.com',
            'volume_mounts' => [{ 'container_dir' => 'mount' }],
            'app_url' => "/v2/apps/#{process.guid}",
            'service_instance_url' => "/v2/service_instances/#{service_instance.guid}"
          }
        }
      )

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.service_binding.create')
      expect(event.actee).to eq(service_binding.guid)
      expect(event.actee_type).to eq('service_binding')
      expect(event.metadata).to match({
        'request' => {
          'type' => 'app',
          'relationships' => {
            'app' => {
              'data' => { 'guid' => process.guid }
            },
            'service_instance' => {
              'data' => { 'guid' => service_instance.guid }
            },
          },
          'data' => 'PRIVATE DATA HIDDEN'
        }
      })
    end
  end

  describe 'DELETE /v2/service_bindings/:guid' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance) }

    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
      end
    end

    it 'deletes the service binding' do
      delete "/v2/service_bindings/#{service_binding.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(204)
      expect(service_binding.exists?).to be_falsey

      event = VCAP::CloudController::Event.last
      expect(event.type).to eq('audit.service_binding.delete')
      expect(event.actee).to eq(service_binding.guid)
      expect(event.actee_type).to eq('service_binding')
      expect(event.metadata).to match(
        {
          'request' => {
            'app_guid' => service_binding.app_guid,
            'service_instance_guid' => service_binding.service_instance_guid,
          }
        }
      )
    end
  end
end
