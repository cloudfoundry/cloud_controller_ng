require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'POST /v3/apps' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make(stack: stack.name) }
    let(:create_request) do
      {
        name: 'my_app',
        environment_variables: { open: 'source' },
        lifecycle: {
          type: 'buildpack',
          data: {
            stack: buildpack.stack,
            buildpacks: [buildpack.name]
          }
        },
        relationships: {
          space: {
            data: {
              guid: space.guid
            }
          }
        },
        metadata: {
          labels: {
            'release' => 'stable',
            'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
          },
          annotations: {
            'description' => 'gud app',
            'dora.capi.land/stuff' => 'real gud stuff'
          }
        }
      }
    end

    context 'permissions for creating an app' do
      let(:api_call) { ->(user_headers) { post '/v3/apps', create_request.to_json, user_headers } }
      let(:app_model_response_object) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'my_app',
          state: 'STOPPED',
          lifecycle: {
            type: 'buildpack',
            data: { buildpacks: [buildpack.name], stack: stack.name }
          },
          relationships: {
            space: { data: { guid: space.guid } },
            current_droplet: { data: { guid: nil } }
          },
          metadata: {
            labels: {
              'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
              'release' => 'stable'
            },
            annotations: {
              'dora.capi.land/stuff' => 'real gud stuff',
              'description' => 'gud app'
            }
          },
          links: {
            self: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}} },
            environment_variables: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/environment_variables} },
            space: { href: %r{#{link_prefix}/v3/spaces/#{space.guid}} },
            processes: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/processes} },
            packages: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/packages} },
            current_droplet: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/droplets/current} },
            droplets: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/droplets} },
            tasks: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/tasks} },
            start: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/actions/start}, method: 'POST' },
            stop: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/actions/stop}, method: 'POST' },
            clear_buildpack_cache: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/actions/clear_buildpack_cache}, method: 'POST' },
            revisions: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/revisions} },
            deployed_revisions: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/revisions/deployed} },
            features: { href: %r{#{link_prefix}/v3/apps/#{UUID_REGEX}/features} }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['org_billing_manager'] = { code: 422 }
        h['org_auditor'] = { code: 422 }
        h['no_role'] = { code: 422 }
        h['admin'] = {
          code: 201,
          response_object: app_model_response_object
        }
        h['space_developer'] = {
          code: 201,
          response_object: app_model_response_object
        }
        h
      end

      before do
        space.organization.add_user(user)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the user can create an app' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'creates an app' do
        post '/v3/apps', create_request.to_json, user_header
        expect(last_response.status).to eq(201)

        parsed_response = Oj.load(last_response.body)
        app_guid = parsed_response['guid']

        expect(VCAP::CloudController::AppModel.find(guid: app_guid)).to be
        expect(parsed_response).to be_a_response_like(
          {
            'name' => 'my_app',
            'guid' => app_guid,
            'state' => 'STOPPED',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {
                'buildpacks' => [buildpack.name],
                'stack' => stack.name
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
                  'guid' => nil
                }
              }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => {
                'release' => 'stable',
                'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
              },
              'annotations' => {
                'description' => 'gud app',
                'dora.capi.land/stuff' => 'real gud stuff'
              }
            },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}" },
              'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/processes" },
              'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/packages" },
              'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/environment_variables" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/droplets/current" },
              'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/droplets" },
              'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/tasks" },
              'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/actions/start", 'method' => 'POST' },
              'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/actions/stop", 'method' => 'POST' },
              'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
              'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/revisions" },
              'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/revisions/deployed" },
              'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/features" }
            }
          }
        )

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
                                          type: 'audit.app.create',
                                          actee: app_guid,
                                          actee_type: 'app',
                                          actee_name: 'my_app',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid
                                        })
      end

      it 'creates an empty web process with the same guid as the app (so it is visible on the v2 apps api)' do
        post '/v3/apps', create_request.to_json, user_header
        expect(last_response.status).to eq(201)

        parsed_response = Oj.load(last_response.body)
        app_guid = parsed_response['guid']
        expect(VCAP::CloudController::AppModel.find(guid: app_guid)).not_to be_nil
        expect(VCAP::CloudController::ProcessModel.find(guid: app_guid)).not_to be_nil
      end

      context 'telemetry' do
        let(:logger_spy) { spy('logger') }

        before do
          allow(VCAP::CloudController::TelemetryLogger).to receive(:logger).and_return(logger_spy)
        end

        it 'logs the required fields when the app is created' do
          Timecop.freeze do
            post '/v3/apps', create_request.to_json, user_header

            parsed_response = Oj.load(last_response.body)
            app_guid = parsed_response['guid']

            expected_json = {
              'telemetry-source' => 'cloud_controller_ng',
              'telemetry-time' => Time.now.to_datetime.rfc3339,
              'create-app' => {
                'api-version' => 'v3',
                'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_guid),
                'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
              }
            }.to_json
            expect(logger_spy).to have_received(:info).with(expected_json)
            expect(last_response.status).to eq(201), last_response.body
          end
        end
      end

      context 'Docker app' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
        end

        it 'create a docker app' do
          create_request = {
            name: 'my_app',
            environment_variables: { open: 'source' },
            lifecycle: {
              type: 'docker',
              data: {}
            },
            relationships: {
              space: { data: { guid: space.guid } }
            }
          }

          post '/v3/apps', create_request.to_json, user_header.merge({ 'CONTENT_TYPE' => 'application/json' })
          expect(last_response.status).to eq(201), last_response.body

          created_app = VCAP::CloudController::AppModel.last
          expected_response = {
            'name' => 'my_app',
            'guid' => created_app.guid,
            'state' => 'STOPPED',
            'lifecycle' => {
              'type' => 'docker',
              'data' => {}
            },
            'relationships' => {
              'space' => {
                'data' => {
                  'guid' => space.guid
                }
              },
              'current_droplet' => {
                'data' => {
                  'guid' => nil
                }
              }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}" },
              'processes' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/processes" },
              'packages' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/packages" },
              'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/environment_variables" },
              'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
              'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/droplets/current" },
              'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/droplets" },
              'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/tasks" },
              'start' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/actions/start", 'method' => 'POST' },
              'stop' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/actions/stop", 'method' => 'POST' },
              'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
              'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/revisions" },
              'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/revisions/deployed" },
              'features' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/features" }
            }
          }

          parsed_response = Oj.load(last_response.body)
          expect(parsed_response).to be_a_response_like(expected_response)

          event = VCAP::CloudController::Event.last
          expect(event.values).to include(
            type: 'audit.app.create',
            actee: created_app.guid,
            actee_type: 'app',
            actee_name: 'my_app',
            actor: user.guid,
            actor_type: 'user',
            actor_name: user_email,
            actor_username: user_name,
            space_guid: space.guid,
            organization_guid: space.organization.guid
          )
        end
      end

      context 'cc.default_app_lifecycle' do
        let(:create_request) do
          {
            name: 'my_app',
            relationships: {
              space: {
                data: {
                  guid: space.guid
                }
              }
            }
          }
        end

        context 'cc.default_app_lifecycle is set to buildpack' do
          before do
            TestConfig.override(default_app_lifecycle: 'buildpack')
          end

          it 'creates an app with the buildpack lifecycle when none is specified in the request' do
            post '/v3/apps', create_request.to_json, user_header

            expect(last_response.status).to eq(201)
            parsed_response = Oj.load(last_response.body)
            expect(parsed_response['lifecycle']['type']).to eq('buildpack')
          end
        end
      end
    end

    context 'stack state validation' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when stack is DISABLED' do
        let(:disabled_stack) { VCAP::CloudController::Stack.make(name: 'disabled-stack', state: 'DISABLED') }
        let(:create_request) do
          {
            name: 'my_app',
            lifecycle: { type: 'buildpack', data: { stack: disabled_stack.name } },
            relationships: { space: { data: { guid: space.guid } } }
          }
        end

        it 'returns 422 with error message' do
          post '/v3/apps', create_request.to_json, user_header

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'].first['detail']).to include('DISABLED')
        end
      end

      context 'when stack is RESTRICTED' do
        let(:restricted_stack) { VCAP::CloudController::Stack.make(name: 'restricted-stack', state: 'RESTRICTED') }
        let(:create_request) do
          {
            name: 'my_app',
            lifecycle: { type: 'buildpack', data: { stack: restricted_stack.name } },
            relationships: { space: { data: { guid: space.guid } } }
          }
        end

        it 'returns 422 with error message for new apps' do
          post '/v3/apps', create_request.to_json, user_header

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'].first['detail']).to include('RESTRICTED')
        end
      end

      context 'when stack is DEPRECATED' do
        let(:deprecated_stack) { VCAP::CloudController::Stack.make(name: 'deprecated-stack', state: 'DEPRECATED') }
        let(:create_request) do
          {
            name: 'my_app',
            lifecycle: { type: 'buildpack', data: { stack: deprecated_stack.name } },
            relationships: { space: { data: { guid: space.guid } } }
          }
        end

        it 'creates the app without warnings in response body' do
          post '/v3/apps', create_request.to_json, user_header

          expect(last_response.status).to eq(201)
          expect(parsed_response).not_to have_key('warnings')
        end

        it 'includes warnings in X-Cf-Warnings header' do
          post '/v3/apps', create_request.to_json, user_header

          expect(last_response.status).to eq(201)
          expect(last_response.headers['X-Cf-Warnings']).to be_present
          decoded_warning = CGI.unescape(last_response.headers['X-Cf-Warnings'])
          expect(decoded_warning).to include('DEPRECATED')
        end
      end

      context 'when stack is ACTIVE' do
        let(:active_stack) { VCAP::CloudController::Stack.make(name: 'active-stack', state: 'ACTIVE') }
        let(:create_request) do
          {
            name: 'my_app',
            lifecycle: { type: 'buildpack', data: { stack: active_stack.name } },
            relationships: { space: { data: { guid: space.guid } } }
          }
        end

        it 'creates the app without warnings' do
          post '/v3/apps', create_request.to_json, user_header

          expect(last_response.status).to eq(201)
          expect(parsed_response).not_to have_key('warnings')
          expect(last_response.headers['X-Cf-Warnings']).to be_nil
        end
      end
    end
  end
end
