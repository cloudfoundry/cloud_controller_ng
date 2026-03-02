require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'GET /v3/apps/:guid' do
    let!(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'bp-name') }
    let!(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let!(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'my_app',
        guid: 'app1_guid',
        space: space,
        desired_state: 'STARTED',
        environment_variables: { 'unicorn' => 'horn' }
      )
    end

    before do
      space.organization.add_user(user)
      app_model.lifecycle_data.buildpacks = [buildpack.name]
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save
      app_model.add_process(VCAP::CloudController::ProcessModel.make(instances: 1))
      app_model.add_process(VCAP::CloudController::ProcessModel.make(instances: 2))
    end

    context 'when getting an app' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}", nil, user_headers } }

      let(:app_model_response_object) do
        {
          guid: app_model.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: app_model.name,
          state: 'STARTED',
          lifecycle: {
            type: 'buildpack',
            data: { buildpacks: [buildpack.name], stack: app_model.lifecycle_data.stack }
          },
          relationships: {
            space: { data: { guid: space.guid } },
            current_droplet: { data: { guid: app_model.droplet_guid } }
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: "#{link_prefix}/v3/apps/app1_guid" },
            environment_variables: { href: "#{link_prefix}/v3/apps/app1_guid/environment_variables" },
            space: { href: "#{link_prefix}/v3/spaces/#{space.guid}" },
            processes: { href: "#{link_prefix}/v3/apps/app1_guid/processes" },
            packages: { href: "#{link_prefix}/v3/apps/app1_guid/packages" },
            current_droplet: { href: "#{link_prefix}/v3/apps/app1_guid/droplets/current" },
            droplets: { href: "#{link_prefix}/v3/apps/app1_guid/droplets" },
            tasks: { href: "#{link_prefix}/v3/apps/app1_guid/tasks" },
            start: { href: "#{link_prefix}/v3/apps/app1_guid/actions/start", method: 'POST' },
            stop: { href: "#{link_prefix}/v3/apps/app1_guid/actions/stop", method: 'POST' },
            clear_buildpack_cache: { href: "#{link_prefix}/v3/apps/app1_guid/actions/clear_buildpack_cache", method: 'POST' },
            revisions: { href: "#{link_prefix}/v3/apps/app1_guid/revisions" },
            deployed_revisions: { href: "#{link_prefix}/v3/apps/app1_guid/revisions/deployed" },
            features: { href: "#{link_prefix}/v3/apps/app1_guid/features" }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: app_model_response_object }.freeze)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the user has permission to view the app' do
      before do
        space.add_developer(user)
      end

      it 'gets a specific app' do
        get "/v3/apps/#{app_model.guid}", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => 'my_app',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {
                'buildpacks' => ['bp-name'],
                'stack' => 'stack-name'
              }
            },
            'relationships' => {
              'space' => {
                'data' => {
                  'guid' => space.guid
                }
              },
              'current_droplet' => {
                'data' => {
                  'guid' => app_model.droplet_guid
                }
              }
            },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
              'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
              'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
              'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
              'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
              'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
              'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
              'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
              'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
              'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
              'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/features" }
            }
          }
        )
      end

      it 'gets a specific app including space' do
        get "/v3/apps/#{app_model.guid}?include=space", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => 'my_app',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {
                'buildpacks' => ['bp-name'],
                'stack' => 'stack-name'
              }
            },
            'relationships' => {
              'space' => {
                'data' => {
                  'guid' => space.guid
                }
              },
              'current_droplet' => {
                'data' => {
                  'guid' => app_model.droplet_guid
                }
              }
            },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
              'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
              'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
              'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
              'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
              'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
              'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
              'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
              'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
              'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
              'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/features" }
            },
            'included' => {
              'spaces' => [{
                'guid' => space.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => space.name,
                'relationships' => {
                  'organization' => {
                    'data' => {
                      'guid' => space.organization.guid
                    }
                  },
                  'quota' => {
                    'data' => nil
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/spaces/#{space.guid}"
                  },
                  'organization' => {
                    'href' => "#{link_prefix}/v3/organizations/#{space.organization.guid}"
                  },
                  'features' => { 'href' => %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}/features} },
                  'apply_manifest' => {
                    'href' => "#{link_prefix}/v3/spaces/#{space.guid}/actions/apply_manifest",
                    'method' => 'POST'
                  }
                }
              }]
            }
          }
        )
      end

      it 'gets a specific app including space and org' do
        get "/v3/apps/#{app_model.guid}?include=space.organization", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        spaces = parsed_response['included']['spaces']
        orgs = parsed_response['included']['organizations']

        expect(spaces).to be_present
        expect(orgs[0]).to be_a_response_like(
          {
            'guid' => org.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'name' => org.name,
            'metadata' => {
              'labels' => {},
              'annotations' => {}
            },
            'suspended' => false,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/organizations/#{org.guid}"
              },
              'default_domain' => {
                'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains/default"
              },
              'domains' => {
                'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains"
              },
              'quota' => {
                'href' => "#{link_prefix}/v3/organization_quotas/#{org.quota_definition.guid}"
              }
            },
            'relationships' => { 'quota' => { 'data' => { 'guid' => org.quota_definition.guid } } }
          }
        )
      end
    end
  end

  describe 'GET /v3/apps/:guid/env' do
    before do
      space.organization.add_user(user)
    end

    context 'when getting an apps environment variables' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/env", nil, user_headers } }
      let!(:app_model) do
        VCAP::CloudController::AppModel.make(
          :buildpack,
          name: 'my_app',
          guid: 'app1_guid',
          space: space,
          environment_variables: { 'unicorn' => 'horn' }
        )
      end

      let(:app_model_response_object) do
        {
          environment_variables: app_model.environment_variables,
          staging_env_json: {},
          running_env_json: {},
          system_env_json: { VCAP_SERVICES: {} },
          application_env_json: anything
        }
      end
      let(:app_model_empty_system_env_response_object) do
        {
          environment_variables: app_model.environment_variables,
          staging_env_json: {},
          running_env_json: {},
          system_env_json: {
            redacted_message: '[PRIVATE DATA HIDDEN]'
          },
          application_env_json: anything
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: app_model_response_object }.freeze)
        h['space_supporter'] = { code: 200, response_object: app_model_empty_system_env_response_object }
        h['global_auditor'] = h['org_manager'] = h['space_manager'] = h['space_auditor'] = { code: 403 }
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when k8s service bindings are enabled' do
        let(:app_model_response_object) do
          r = super()
          r[:system_env_json] = { SERVICE_BINDING_ROOT: '/etc/cf-service-bindings' }
          r
        end

        before do
          app_model.update(service_binding_k8s_enabled: true)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when file-based VCAP service bindings are enabled' do
        let(:app_model_response_object) do
          r = super()
          r[:system_env_json] = { VCAP_SERVICES_FILE_PATH: '/etc/cf-service-bindings/vcap_services' }
          r
        end

        before do
          app_model.update(file_based_vcap_services_enabled: true)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when VCAP_SERVICES contains potentially sensitive information' do
      before do
        group = VCAP::CloudController::EnvironmentVariableGroup.staging
        group.environment_json = { STAGING_ENV: 'staging_value' }
        group.save

        group = VCAP::CloudController::EnvironmentVariableGroup.running
        group.environment_json = { RUNNING_ENV: 'running_value' }
        group.save
      end

      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/env", nil, user_headers } }
      let(:app_model) do
        VCAP::CloudController::AppModel.make(
          name: 'my_app',
          space: space,
          environment_variables: { 'unicorn' => 'horn' }
        )
      end
      let(:service_instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          space: space,
          name: 'si-name',
          tags: ['50% off']
        )
      end
      let(:service_binding) do
        VCAP::CloudController::ServiceBinding.make(
          service_instance: service_instance,
          app: app_model,
          syslog_drain_url: 'https://syslog.example.com/drain',
          credentials: { password: 'top-secret' }
        )
      end
      let(:expected_response) do
        {
          'staging_env_json' => {
            'STAGING_ENV' => 'staging_value'
          },
          'running_env_json' => {
            'RUNNING_ENV' => 'running_value'
          },
          'environment_variables' => {
            'unicorn' => 'horn'
          },
          'system_env_json' => {
            'VCAP_SERVICES' => {
              service_instance.service.label => [
                {
                  'name' => 'si-name',
                  'instance_guid' => service_instance.guid,
                  'instance_name' => 'si-name',
                  'binding_guid' => service_binding.guid,
                  'binding_name' => nil,
                  'credentials' => { 'password' => 'top-secret' },
                  'syslog_drain_url' => 'https://syslog.example.com/drain',
                  'volume_mounts' => [],
                  'label' => service_instance.service.label,
                  'provider' => nil,
                  'plan' => service_instance.service_plan.name,
                  'tags' => ['50% off']
                }
              ]
            }
          },
          'application_env_json' => {
            'VCAP_APPLICATION' => {
              'cf_api' => "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
              'limits' => {
                'fds' => 16_384
              },
              'application_name' => 'my_app',
              'application_uris' => [],
              'name' => 'my_app',
              'organization_id' => space.organization.guid,
              'organization_name' => space.organization.name,
              'space_id' => space.guid,
              'space_name' => space.name,
              'uris' => [],
              'users' => nil,
              'application_id' => app_model.guid
            }
          }
        }
      end

      let(:expected_response_system_env_redacted) do
        {
          'staging_env_json' => {
            'STAGING_ENV' => 'staging_value'
          },
          'running_env_json' => {
            'RUNNING_ENV' => 'running_value'
          },
          'environment_variables' => {
            'unicorn' => 'horn'
          },
          'system_env_json' => {
            'redacted_message' => '[PRIVATE DATA HIDDEN]'
          },
          'application_env_json' => {
            'VCAP_APPLICATION' => {
              'cf_api' => "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
              'limits' => {
                'fds' => 16_384
              },
              'application_name' => 'my_app',
              'application_uris' => [],
              'name' => 'my_app',
              'organization_id' => space.organization.guid,
              'organization_name' => space.organization.name,
              'space_id' => space.guid,
              'space_name' => space.name,
              'uris' => [],
              'users' => nil,
              'application_id' => app_model.guid
            }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403 }.freeze)
        h['admin'] = h['admin_read_only'] = h['space_developer'] = { code: 200, response_object: expected_response }
        h['space_supporter'] = { code: 200, response_object: expected_response_system_env_redacted }
        h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the space_developer_env_var_visibility feature flag is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'space_developer_env_var_visibility', enabled: false, error_message: nil)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            h = Hash.new({ code: 403 }.freeze)
            h['admin'] = h['admin_read_only'] = { code: 200, response_object: expected_response }
            h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
            h
          end
        end
      end
    end
  end
end
