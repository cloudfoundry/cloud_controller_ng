require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'DELETE /v3/apps/guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
    let!(:package) { VCAP::CloudController::PackageModel.make(app: app_model) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(package: package, app: app_model) }
    let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }
    let!(:deployment) { VCAP::CloudController::DeploymentModel.make(app: app_model) }
    let(:user_email) { nil }

    it 'deletes an App' do
      space.organization.add_user(user)
      space.add_developer(user)
      delete "/v3/apps/#{app_model.guid}", nil, user_header

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r{/v3/jobs/#{VCAP::CloudController::PollableJobModel.last.guid}})

      Delayed::Worker.new.work_off

      expect(app_model).not_to exist
      expect(package).not_to exist
      expect(droplet).not_to exist
      expect(process).not_to exist
      expect(deployment).not_to exist

      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
                                        type: 'audit.app.delete-request',
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: 'app_name',
                                        actor: user.guid,
                                        actor_type: 'user',
                                        actor_name: '',
                                        actor_username: user_name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
    end

    context 'permissions for deleting an app' do
      let(:api_call) { ->(user_headers) { delete "/v3/apps/#{app_model.guid}", nil, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 202 }.freeze)
        %w[admin_read_only global_auditor org_manager space_auditor space_manager space_supporter].each do |r|
          h[r] = { code: 403, errors: CF_NOT_AUTHORIZED }
        end
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
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

    context 'deleting metadata' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it_behaves_like 'resource with metadata' do
        let(:resource) { app_model }
        let(:api_call) do
          -> { delete "/v3/apps/#{resource.guid}", nil, user_header }
        end
      end
    end
  end

  describe 'PATCH /v3/apps/:guid' do
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'original_name',
        space: space,
        environment_variables: { 'ORIGINAL' => 'ENVAR' },
        desired_state: 'STOPPED'
      )
    end
    let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STOPPED) }
    let(:stack) { VCAP::CloudController::Stack.make(name: 'redhat') }

    let(:update_request) do
      {
        name: 'new-name',
        lifecycle: {
          type: 'buildpack',
          data: {
            buildpacks: ['http://gitwheel.org/my-app'],
            stack: stack.name
          }
        },
        metadata: {
          labels: {
            'release' => 'stable',
            'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
            'delete-me' => nil
          },
          annotations: {
            'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
            'anno1' => 'new-value',
            'please' => nil
          }
        }
      }
    end

    let(:expected_response_object) do
      {
        'name' => 'new-name',
        'guid' => app_model.guid,
        'state' => 'STOPPED',
        'lifecycle' => {
          'type' => 'buildpack',
          'data' => {
            'buildpacks' => ['http://gitwheel.org/my-app'],
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
            'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
            'anno1' => 'new-value'
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
    end

    before do
      VCAP::CloudController::AppLabelModel.make(
        resource_guid: app_model.guid,
        key_name: 'delete-me',
        value: 'yes'
      )

      VCAP::CloudController::AppAnnotationModel.make(
        resource_guid: app_model.guid,
        key_name: 'anno1',
        value: 'original-value'
      )

      VCAP::CloudController::AppAnnotationModel.make(
        resource_guid: app_model.guid,
        key_name: 'please',
        value: 'delete this'
      )
    end

    it 'updates an app' do
      space.organization.add_user(user)
      space.add_developer(user)
      expect_any_instance_of(VCAP::CloudController::Diego::Runner).not_to receive(:update_metric_tags)
      patch "/v3/apps/#{app_model.guid}", update_request.to_json, user_header
      expect(last_response.status).to eq(200)

      app_model.reload

      parsed_response = Oj.load(last_response.body)
      expect(parsed_response).to be_a_response_like(expected_response_object)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.app.update',
                                        actee: app_model.guid,
                                        actee_type: 'app',
                                        actee_name: 'new-name',
                                        actor: user.guid,
                                        actor_type: 'user',
                                        actor_name: user_email,
                                        actor_username: user_name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      metadata_request = {
        'name' => 'new-name',
        'lifecycle' => {
          'type' => 'buildpack',
          'data' => {
            'buildpacks' => ['http://gitwheel.org/my-app'],
            'stack' => stack.name
          }
        },
        'metadata' => {
          'labels' => {
            'release' => 'stable',
            'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
            'delete-me' => nil
          },
          'annotations' => {
            'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
            'anno1' => 'new-value',
            'please' => nil
          }
        }
      }
      expect(event.metadata['request']).to eq(metadata_request)
    end

    context 'when the app has a process that is started' do
      let!(:web_process) { VCAP::CloudController::ProcessModel.make(app: app_model, state: VCAP::CloudController::ProcessModel::STARTED) }

      before do
        app_model.desired_state = VCAP::CloudController::ProcessModel::STARTED
      end

      it 'notifies diego that an app has been renamed' do
        space.organization.add_user(user)
        space.add_developer(user)
        expect_any_instance_of(VCAP::CloudController::Diego::Runner).to receive(:update_metric_tags)
        patch "/v3/apps/#{app_model.guid}", update_request.to_json, user_header
        expect(last_response.status).to eq(200)
      end
    end

    context 'permissions for updating an app' do
      let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}", update_request.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_object: expected_response_object }.freeze)
        %w[admin_read_only global_auditor org_manager space_auditor space_manager space_supporter].each do |r|
          h[r] = { code: 403, errors: CF_NOT_AUTHORIZED }
        end
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
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

    context 'telemetry' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'logs the required fields when the app gets updated' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'update-app' => {
              'api-version' => 'v3',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

          patch "/v3/apps/#{app_model.guid}", update_request.to_json, user_header
          expect(last_response.status).to eq(200), last_response.body
        end
      end
    end
  end
end
