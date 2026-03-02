require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'POST /v3/apps/:guid/actions/start' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'app-name',
        space: space,
        desired_state: 'STOPPED'
      )
    end

    context 'app lifecycle is buildpack' do
      let!(:droplet) do
        VCAP::CloudController::DropletModel.make(
          :buildpack,
          app: app_model,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end

      before do
        app_model.lifecycle_data.buildpacks = ['http://example.com/git']
        app_model.lifecycle_data.stack = stack.name
        app_model.lifecycle_data.save
        app_model.droplet = droplet
        app_model.save
      end

      context 'starting an app' do
        let(:api_call) { ->(user_headers) { post "/v3/apps/#{app_model.guid}/actions/start", nil, user_headers } }
        let(:app_start_response_object) do
          {
            'name' => 'app-name',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {
                'buildpacks' => ['http://example.com/git'],
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
                  'guid' => droplet.guid
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
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          h['no_role'] = { code: 404 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['admin'] = {
            code: 200,
            response_object: app_start_response_object
          }
          h['space_supporter'] = {
            code: 200,
            response_object: app_start_response_object
          }
          h['space_developer'] = {
            code: 200,
            response_object: app_start_response_object
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

        describe 'limiting the application log rates' do
          let(:log_rate_limit) { -1 }
          let(:space_log_rate_limit) { -1 }
          let(:org_log_rate_limit) { -1 }
          let(:org_quota_definition) { VCAP::CloudController::QuotaDefinition.make(log_rate_limit: org_log_rate_limit) }
          let(:org) { VCAP::CloudController::Organization.make(quota_definition: org_quota_definition) }
          let(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, log_rate_limit: space_log_rate_limit) }
          let(:space) { VCAP::CloudController::Space.make(organization: org, space_quota_definition: space_quota_definition) }
          let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model, log_rate_limit: log_rate_limit) }
          let(:app_model) do
            VCAP::CloudController::AppModel.make(
              :buildpack,
              name: 'app-name',
              space: space,
              desired_state: 'STOPPED'
            )
          end
          let(:droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'webby' }) }

          before do
            app_model.update(droplet_guid: droplet.guid)
          end

          describe 'space quotas' do
            context 'when both the space and the app do not specify a log rate limit' do
              let(:log_rate_limit) { -1 }
              let(:space_log_rate_limit) { -1 }

              it 'starts the app successfully' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(200)
              end
            end

            context "when the app fits in the space's log rate limit" do
              let(:log_rate_limit) { 199 }
              let(:space_log_rate_limit) { 200 }

              it 'starts the app successfully' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(200)
              end
            end

            context "when the app's log rate limit is unspecified, but the space specifies a log rate limit" do
              let(:log_rate_limit) { -1 }
              let(:space_log_rate_limit) { 200 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message("log_rate_limit cannot be unlimited in space '#{space.name}'.")
              end
            end

            context "when the app's log rate limit is larger than the limit specified by the space" do
              let(:log_rate_limit) { 201 }
              let(:space_log_rate_limit) { 200 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message('log_rate_limit exceeds space log rate quota')
              end
            end

            context "when the space's quota is more strict that the org's quota, the space quota controls" do
              let(:log_rate_limit) { 201 }
              let(:space_log_rate_limit) { 200 }
              let(:org_log_rate_limit) { 201 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message('log_rate_limit exceeds space log rate quota')
              end
            end
          end

          describe 'organization quotas' do
            context 'when both the org and the app do not specify a log rate limit' do
              let(:log_rate_limit) { -1 }
              let(:org_log_rate_limit) { -1 }

              it 'starts the app successfully' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(200)
              end
            end

            context "when the app fits in the org's log rate limit" do
              let(:log_rate_limit) { 199 }
              let(:org_log_rate_limit) { 200 }

              it 'starts the app successfully' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(200)
              end
            end

            context "when the app's log rate limit is unspecified, but the org specifies a log rate limit" do
              let(:log_rate_limit) { -1 }
              let(:org_log_rate_limit) { 200 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message("log_rate_limit cannot be unlimited in organization '#{org.name}'.")
              end
            end

            context "when the app's log rate limit is larger than the limit specified by the org" do
              let(:log_rate_limit) { 201 }
              let(:org_log_rate_limit) { 200 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message('log_rate_limit exceeds organization log rate quota')
              end
            end

            context "when the org's quota is more strict that the space's quota, the org quota controls" do
              let(:log_rate_limit) { 201 }
              let(:space_log_rate_limit) { 202 }
              let(:org_log_rate_limit) { 200 }

              it 'fails to start the app' do
                post "/v3/apps/#{app_model.guid}/actions/start", nil, admin_header

                expect(last_response.status).to eq(422)
                expect(last_response).to have_error_message('log_rate_limit exceeds organization log rate quota')
              end
            end
          end
        end
      end

      context 'events' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'issues the required events when the app starts' do
          post "/v3/apps/#{app_model.guid}/actions/start", nil, user_header

          event = VCAP::CloudController::Event.last
          expect(event.values).to include({
                                            type: 'audit.app.start',
                                            actee: app_model.guid,
                                            actee_type: 'app',
                                            actee_name: 'app-name',
                                            actor: user.guid,
                                            actor_type: 'user',
                                            actor_name: user_email,
                                            actor_username: user_name,
                                            space_guid: space.guid,
                                            organization_guid: space.organization.guid
                                          })
        end
      end

      context 'telemetry' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'logs the required fields when the app starts' do
          Timecop.freeze do
            expected_json = {
              'telemetry-source' => 'cloud_controller_ng',
              'telemetry-time' => Time.now.to_datetime.rfc3339,
              'start-app' => {
                'api-version' => 'v3',
                'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
                'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
              }
            }
            expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))
            post "/v3/apps/#{app_model.guid}/actions/start", nil, user_header

            expect(last_response.status).to eq(200), last_response.body
          end
        end
      end
    end

    describe 'when there is a new desired droplet and revision feature is turned on' do
      let(:droplet) do
        VCAP::CloudController::DropletModel.make(
          app: app_model,
          process_types: { web: 'rackup' },
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          package: VCAP::CloudController::PackageModel.make
        )
      end

      before do
        space.organization.add_user(user)
        space.add_developer(user)
        app_model.update(revisions_enabled: true)
      end

      it 'creates a new revision' do
        expect do
          patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", { data: { guid: droplet.guid } }.to_json, user_header
          expect(last_response.status).to eq(200)
        end.not_to(change(VCAP::CloudController::RevisionModel, :count))

        expect do
          post "/v3/apps/#{app_model.guid}/actions/start", nil, user_header
          expect(last_response.status).to eq(200), last_response.body
        end.to change(VCAP::CloudController::RevisionModel, :count).by(1)
      end
    end
  end

  describe 'POST /v3/apps/:guid/actions/stop' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'app-name',
        space: space,
        desired_state: 'STARTED'
      )
    end
    let!(:droplet) do
      VCAP::CloudController::DropletModel.make(:buildpack,
                                               app: app_model,
                                               state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end

    before do
      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save
      app_model.droplet = droplet
      app_model.save
    end

    context 'stopping an app' do
      let(:api_call) { ->(user_headers) { post "/v3/apps/#{app_model.guid}/actions/stop", nil, user_headers } }
      let(:app_stop_response_object) do
        {
          'name' => 'app-name',
          'guid' => app_model.guid,
          'state' => 'STOPPED',
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['http://example.com/git'],
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
                'guid' => droplet.guid
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
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['no_role'] = { code: 404 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['admin'] = {
          code: 200,
          response_object: app_stop_response_object
        }
        h['space_supporter'] = {
          code: 200,
          response_object: app_stop_response_object
        }
        h['space_developer'] = {
          code: 200,
          response_object: app_stop_response_object
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

      it 'issues the required events when the app stops' do
        post "/v3/apps/#{app_model.guid}/actions/stop", nil, user_header

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
                                          type: 'audit.app.stop',
                                          actee: app_model.guid,
                                          actee_type: 'app',
                                          actee_name: 'app-name',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid
                                        })
      end
    end

    context 'telemetry' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'logs the required fields when the app stops' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'stop-app' => {
              'api-version' => 'v3',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

          post "/v3/apps/#{app_model.guid}/actions/stop", nil, user_header

          expect(last_response.status).to eq(200), last_response.body
        end
      end
    end
  end

  describe 'POST /v3/apps/:guid/actions/restart' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'app-name',
        space: space,
        desired_state: 'STARTED'
      )
    end

    context 'app lifecycle is buildpack' do
      let!(:droplet) do
        VCAP::CloudController::DropletModel.make(
          :buildpack,
          app: app_model,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end

      before do
        app_model.lifecycle_data.buildpacks = ['http://example.com/git']
        app_model.lifecycle_data.stack = stack.name
        app_model.lifecycle_data.save
        app_model.droplet = droplet
        app_model.save
      end

      context 'restarting an app' do
        let(:api_call) { ->(user_headers) { post "/v3/apps/#{app_model.guid}/actions/restart", nil, user_headers } }
        let(:app_restart_response_object) do
          {
            'name' => 'app-name',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {
                'buildpacks' => ['http://example.com/git'],
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
                  'guid' => droplet.guid
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
        end

        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
          h['no_role'] = { code: 404 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['admin'] = {
            code: 200,
            response_object: app_restart_response_object
          }
          h['space_supporter'] = {
            code: 200,
            response_object: app_restart_response_object
          }
          h['space_developer'] = {
            code: 200,
            response_object: app_restart_response_object
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

      context 'telemetry' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'logs the required fields when the app is restarted' do
          Timecop.freeze do
            expected_json = {
              'telemetry-source' => 'cloud_controller_ng',
              'telemetry-time' => Time.now.to_datetime.rfc3339,
              'restart-app' => {
                'api-version' => 'v3',
                'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
                'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
              }
            }
            expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

            post "/v3/apps/#{app_model.guid}/actions/restart", nil, user_header

            expect(last_response.status).to eq(200), last_response.body
          end
        end
      end
    end
  end
end
