require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'GET /v3/apps/:guid/relationships/current_droplet' do
    let(:api_call) { ->(user_headers) { get "/v3/apps/#{droplet_model.app_guid}/relationships/current_droplet", nil, user_headers } }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let!(:droplet_model) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
    let(:expected_response) do
      {
        'data' => {
          'guid' => droplet_model.guid
        },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/apps/#{droplet_model.app_guid}/relationships/current_droplet" },
          'related' => { 'href' => "#{link_prefix}/v3/apps/#{droplet_model.app_guid}/droplets/current" }
        }
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 200, response_object: expected_response }.freeze)
      h['no_role'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
      h['org_auditor'] = { code: 404 }
      h
    end

    before do
      app_model.droplet_guid = droplet_model.guid
      app_model.save
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'GET /v3/apps/:guid/droplets/current' do
    let(:api_call) { ->(user_headers) { get "/v3/apps/#{droplet_model.app_guid}/droplets/current", nil, user_headers } }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: 'example error',
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        sha256_checksum: 'droplet-sha256-checksum',
        process_types: { 'web' => 'start-command' }
      )
    end
    let(:expected_response) do
      {
        'guid' => droplet_model.guid,
        'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
        'error' => 'example error',
        'lifecycle' => {
          'type' => 'buildpack',
          'data' => {}
        },
        'checksum' => { 'type' => 'sha256', 'value' => 'droplet-sha256-checksum' },
        'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
        'stack' => 'stack-name',
        'execution_metadata' => 'some-data',
        'process_types' => { 'web' => 'start-command' },
        'image' => nil,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet_model.guid}" },
          'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          'download' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet_model.guid}/download" },
          'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' }
        },
        'metadata' => {
          'labels' => {},
          'annotations' => {}
        }
      }
    end
    let(:expected_codes_and_responses) do
      h = Hash.new({ code: 200, response_object: expected_response }.freeze)
      h['no_role'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
      h['org_auditor'] = { code: 404 }
      h
    end

    before do
      droplet_model.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
      app_model.droplet_guid = droplet_model.guid
      app_model.save
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'PATCH /v3/apps/:guid/relationships/current_droplet' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'my_app',
        space: space,
        desired_state: 'STOPPED'
      )
    end
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        :docker,
        app: app_model,
        process_types: { web: 'rackup' },
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        package: VCAP::CloudController::PackageModel.make
      )
    end
    let(:request_body) { { data: { guid: droplet.guid } } }

    before do
      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save
    end

    context 'assigning the current droplet of the app' do
      let(:api_call) { ->(user_headers) { patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_headers } }
      let(:current_droplet_response_object) do
        {
          'data' => {
            'guid' => droplet.guid
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet" },
            'related' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['no_role'] = { code: 404 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['admin'] = {
          code: 200,
          response_object: current_droplet_response_object
        }
        h['space_supporter'] = {
          code: 200,
          response_object: current_droplet_response_object
        }
        h['space_developer'] = {
          code: 200,
          response_object: current_droplet_response_object
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
          %w[space_supporter space_developer].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'events' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'creates audit.app.droplet.mapped event' do
        patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

        events = VCAP::CloudController::Event.where(actor: user.guid).all

        droplet_event = events.find { |e| e.type == 'audit.app.droplet.mapped' }
        expect(droplet_event.values).to include({
                                                  type: 'audit.app.droplet.mapped',
                                                  actee: app_model.guid,
                                                  actee_type: 'app',
                                                  actee_name: 'my_app',
                                                  actor: user.guid,
                                                  actor_type: 'user',
                                                  actor_name: user_email,
                                                  actor_username: user_name,
                                                  space_guid: space.guid,
                                                  organization_guid: space.organization.guid
                                                })
        expect(droplet_event.metadata).to eq({ 'request' => { 'droplet_guid' => droplet.guid } })

        expect(app_model.reload.processes.count).to eq(1)
      end

      context 'with two process types' do
        let(:droplet) do
          VCAP::CloudController::DropletModel.make(
            app: app_model,
            process_types: { web: 'rackup', other: 'cron' },
            state: VCAP::CloudController::DropletModel::STAGED_STATE
          )
        end

        it 'creates audit.app.process.create events for each process' do
          patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

          expect(last_response.status).to eq(200)

          events = VCAP::CloudController::Event.where(actor: user.guid).all

          expect(app_model.reload.processes.count).to eq(2)
          web_process = app_model.processes.find { |i| i.type == 'web' }
          other_process = app_model.processes.find { |i| i.type == 'other' }
          expect(web_process).to be_present
          expect(other_process).to be_present

          web_process_event = events.find { |e| e.metadata['process_guid'] == web_process.guid }
          expect(web_process_event.values).to include({
                                                        type: 'audit.app.process.create',
                                                        actee: app_model.guid,
                                                        actee_type: 'app',
                                                        actee_name: 'my_app',
                                                        actor: user.guid,
                                                        actor_type: 'user',
                                                        actor_name: user_email,
                                                        actor_username: user_name,
                                                        space_guid: space.guid,
                                                        organization_guid: space.organization.guid
                                                      })
          expect(web_process_event.metadata).to eq({ 'process_guid' => web_process.guid, 'process_type' => 'web' })

          other_process_event = events.find { |e| e.metadata['process_guid'] == other_process.guid }
          expect(other_process_event.values).to include({
                                                          type: 'audit.app.process.create',
                                                          actee: app_model.guid,
                                                          actee_type: 'app',
                                                          actee_name: 'my_app',
                                                          actor: user.guid,
                                                          actor_type: 'user',
                                                          actor_name: user_email,
                                                          actor_username: user_name,
                                                          space_guid: space.guid,
                                                          organization_guid: space.organization.guid
                                                        })
          expect(other_process_event.metadata).to eq({ 'process_guid' => other_process.guid, 'process_type' => 'other' })
        end
      end
    end

    context 'sidecars' do
      let(:droplet) do
        VCAP::CloudController::DropletModel.make(
          :docker,
          app: app_model,
          process_types: { web: 'rackup' },
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          package: VCAP::CloudController::PackageModel.make,
          sidecars:
            [
              {
                name: 'sidecar_one',
                command: 'bundle exec rackup',
                process_types: ['web'],
                memory: 300
              }
            ]
        )
      end

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'creates sidecars that were saved on the droplet' do
        patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

        expect(last_response.status).to eq(200)

        expect(app_model.reload.processes.count).to eq(1)
        expect(app_model.reload.sidecars.count).to eq(1)
      end

      it 'logs the create-sidecar event' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-sidecar' => {
              'api-version' => 'v3',
              'origin' => 'buildpack',
              'memory-in-mb' => 300,
              'process-types' => ['web'],
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

          patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

          expect(last_response.status).to eq(200), last_response.body
        end
      end
    end
  end
end
