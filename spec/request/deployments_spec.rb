require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Deployments' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }
  let(:app_model) { VCAP::CloudController::AppModel.make(desired_state: VCAP::CloudController::ProcessModel::STARTED) }
  let(:droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'webby' }) }
  let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model) }
  let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }
  let(:metadata) { { 'labels' => {}, 'annotations' => {} } }

  before do
    TestConfig.override(temporary_disable_deployments: false)
    app_model.update(droplet_guid: droplet.guid)
  end

  describe 'POST /v3/deployments' do
    context 'when a droplet is not supplied with the request' do
      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end
      let(:expected_response) do
        {
          'guid' => UUID_REGEX,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601,
              'last_status_change' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => droplet.guid
          },
          'revision' => {
            'guid' => UUID_REGEX,
            'version' => 1
          },
          'previous_droplet' => {
            'guid' => droplet.guid
          },
          'new_processes' => [{
            'guid' => UUID_REGEX,
            'type' => 'web'
          }],
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'metadata' => metadata,
          'relationships' => {
            'app' => {
              'data' => {
                'guid' => app_model.guid
              }
            }
          },
          'links' => {
            'self' => {
              'href' => %r{#{link_prefix}/v3/deployments/#{UUID_REGEX}}
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
            },
            'cancel' => {
              'href' => %r{#{link_prefix}/v3/deployments/#{UUID_REGEX}/actions/cancel},
              'method' => 'POST'
            }
          }
        }
      end
      let(:api_call) { ->(user_headers) { post '/v3/deployments', create_request.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 422)
        h['admin'] = h['space_developer'] = h['space_supporter'] = { code: 201, response_object: expected_response }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 422 } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when a droplet is supplied with the request' do
      let(:user) { make_developer_for_space(space) }
      let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'start-me-up' }) }
      let(:create_request) do
        {
          droplet: {
            guid: other_droplet.guid
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      it 'creates a deployment object with that droplet' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)
        parsed_response = Oj.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last

        expect(parsed_response).to be_a_response_like({
                                                        'guid' => deployment.guid,
                                                        'status' => {
                                                          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                          'details' => {
                                                            'last_successful_healthcheck' => iso8601,
                                                            'last_status_change' => iso8601
                                                          }
                                                        },
                                                        'strategy' => 'rolling',
                                                        'droplet' => {
                                                          'guid' => other_droplet.guid
                                                        },
                                                        'revision' => {
                                                          'guid' => app_model.latest_revision.guid,
                                                          'version' => app_model.latest_revision.version
                                                        },
                                                        'previous_droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'new_processes' => [{
                                                          'guid' => deployment.deploying_web_process.guid,
                                                          'type' => deployment.deploying_web_process.type
                                                        }],
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'metadata' => metadata,
                                                        'relationships' => {
                                                          'app' => {
                                                            'data' => {
                                                              'guid' => app_model.guid
                                                            }
                                                          }
                                                        },
                                                        'links' => {
                                                          'self' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                          },
                                                          'app' => {
                                                            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                          },
                                                          'cancel' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                            'method' => 'POST'
                                                          }
                                                        }
                                                      })
      end
    end

    context 'when a revision is supplied with the request' do
      let(:user) { make_developer_for_space(space) }
      let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'webby' }) }
      let!(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, droplet: other_droplet, created_at: 5.days.ago) }
      let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, droplet: droplet) }

      let(:create_request) do
        {
          revision: {
            guid: revision.guid
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      it 'creates a deployment object using the droplet associated with the revision' do
        revision_count = VCAP::CloudController::RevisionModel.count
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201), last_response.body
        expect(VCAP::CloudController::RevisionModel.count).to eq(revision_count + 1)

        parsed_response = Oj.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last
        revision = VCAP::CloudController::RevisionModel.last

        expect(parsed_response).to be_a_response_like({
                                                        'guid' => deployment.guid,
                                                        'status' => {
                                                          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                          'details' => {
                                                            'last_successful_healthcheck' => iso8601,
                                                            'last_status_change' => iso8601
                                                          }
                                                        },
                                                        'strategy' => 'rolling',
                                                        'droplet' => {
                                                          'guid' => other_droplet.guid
                                                        },
                                                        'revision' => {
                                                          'guid' => revision.guid,
                                                          'version' => revision.version
                                                        },
                                                        'previous_droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'new_processes' => [{
                                                          'guid' => deployment.deploying_web_process.guid,
                                                          'type' => deployment.deploying_web_process.type
                                                        }],
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'metadata' => metadata,
                                                        'relationships' => {
                                                          'app' => {
                                                            'data' => {
                                                              'guid' => app_model.guid
                                                            }
                                                          }
                                                        },
                                                        'links' => {
                                                          'self' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                          },
                                                          'app' => {
                                                            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                          },
                                                          'cancel' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                            'method' => 'POST'
                                                          }
                                                        }
                                                      })
      end
    end

    context 'when a revision AND a droplet are supplied with the request' do
      let(:create_request) do
        {
          revision: {
            guid: 'bar'
          },
          droplet: {
            guid: 'foo'
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      it 'fails' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(422)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['errors'][0]['detail']).to match('Cannot set both fields')
      end
    end

    context 'when metadata is supplied with the request' do
      let(:metadata) do
        {
          'labels' => {
            release: 'stable',
            'seriouseats.com/potato' => 'mashed'
          },
          'annotations' => {
            potato: 'idaho'
          }
        }
      end
      let(:user) { make_developer_for_space(space) }

      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          },
          metadata: metadata
        }
      end

      it 'creates a deployment object with the metadata' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)

        deployment = VCAP::CloudController::DeploymentModel.last
        expect(deployment).to have_labels(
          { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
          { prefix: nil, key_name: 'release', value: 'stable' }
        )
        expect(deployment).to have_annotations(
          { key_name: 'potato', value: 'idaho' }
        )

        expect(parsed_response).to be_a_response_like({
                                                        'guid' => deployment.guid,
                                                        'status' => {
                                                          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                          'details' => {
                                                            'last_successful_healthcheck' => iso8601,
                                                            'last_status_change' => iso8601
                                                          }
                                                        },
                                                        'strategy' => 'rolling',
                                                        'droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'revision' => {
                                                          'guid' => app_model.latest_revision.guid,
                                                          'version' => app_model.latest_revision.version
                                                        },
                                                        'previous_droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'new_processes' => [{
                                                          'guid' => deployment.deploying_web_process.guid,
                                                          'type' => deployment.deploying_web_process.type
                                                        }],
                                                        'metadata' => { 'labels' => { 'release' => 'stable', 'seriouseats.com/potato' => 'mashed' },
                                                                        'annotations' => { 'potato' => 'idaho' } },
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'relationships' => {
                                                          'app' => {
                                                            'data' => {
                                                              'guid' => app_model.guid
                                                            }
                                                          }
                                                        },
                                                        'links' => {
                                                          'self' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                          },
                                                          'app' => {
                                                            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                          },
                                                          'cancel' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                            'method' => 'POST'
                                                          }
                                                        }
                                                      })
      end
    end

    context 'when revisions are enabled' do
      let(:user) { make_developer_for_space(space) }
      let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'start-me-up' }) }
      let(:create_request) do
        {
          droplet: {
            guid: other_droplet.guid
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      it 'creates a deployment with a reference to the new revision' do
        expect do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body
        end.to change(VCAP::CloudController::RevisionModel, :count).by(1)

        deployment = VCAP::CloudController::DeploymentModel.last
        revision = VCAP::CloudController::RevisionModel.last
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
                                                        'guid' => deployment.guid,
                                                        'status' => {
                                                          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                          'details' => {
                                                            'last_successful_healthcheck' => iso8601,
                                                            'last_status_change' => iso8601
                                                          }
                                                        },
                                                        'strategy' => 'rolling',
                                                        'droplet' => {
                                                          'guid' => other_droplet.guid
                                                        },
                                                        'revision' => {
                                                          'guid' => revision.guid,
                                                          'version' => revision.version
                                                        },
                                                        'previous_droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'new_processes' => [{
                                                          'guid' => deployment.deploying_web_process.guid,
                                                          'type' => deployment.deploying_web_process.type
                                                        }],
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'metadata' => metadata,
                                                        'relationships' => {
                                                          'app' => {
                                                            'data' => {
                                                              'guid' => app_model.guid
                                                            }
                                                          }
                                                        },
                                                        'links' => {
                                                          'self' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                          },
                                                          'app' => {
                                                            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                          },
                                                          'cancel' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                            'method' => 'POST'
                                                          }
                                                        }
                                                      })
      end
    end

    context 'when the app is stopped' do
      let(:user) { make_developer_for_space(space) }
      let(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'start-me-up' }) }
      let(:create_request) do
        {
          droplet: {
            guid: other_droplet.guid
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      before do
        app_model.update(desired_state: VCAP::CloudController::ProcessModel::STOPPED)
        app_model.save
      end

      it 'creates a deployment object in state DEPLOYED' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)
        parsed_response = Oj.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last

        expect(parsed_response).to be_a_response_like({
                                                        'guid' => deployment.guid,
                                                        'status' => {
                                                          'value' => VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                                          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON,
                                                          'details' => {
                                                            'last_successful_healthcheck' => iso8601,
                                                            'last_status_change' => iso8601
                                                          }
                                                        },
                                                        'strategy' => 'rolling',
                                                        'droplet' => {
                                                          'guid' => other_droplet.guid
                                                        },
                                                        'revision' => {
                                                          'guid' => app_model.latest_revision.guid,
                                                          'version' => app_model.latest_revision.version
                                                        },
                                                        'previous_droplet' => {
                                                          'guid' => droplet.guid
                                                        },
                                                        'new_processes' => [],
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'metadata' => metadata,
                                                        'relationships' => {
                                                          'app' => {
                                                            'data' => {
                                                              'guid' => app_model.guid
                                                            }
                                                          }
                                                        },
                                                        'links' => {
                                                          'self' => {
                                                            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                          },
                                                          'app' => {
                                                            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                          }
                                                        }
                                                      })
      end

      it 'starts the app' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)

        expect(app_model.reload.desired_state).to eq(VCAP::CloudController::ProcessModel::STARTED)
      end

      context 'when "strategy":"rolling" is provided' do
        it 'starts the app' do
          post '/v3/deployments', create_request.merge({ strategy: 'rolling' }).to_json, user_header
          expect(last_response.status).to eq(201)

          expect(app_model.reload.desired_state).to eq(VCAP::CloudController::ProcessModel::STARTED)
        end
      end
    end

    context 'telemetry' do
      let!(:other_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'webboo' }) }
      let!(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, droplet: other_droplet, created_at: 5.days.ago) }
      let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, droplet: droplet) }
      let(:user) { make_developer_for_space(space) }

      let(:create_request) do
        {
          strategy: 'canary',
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end
      let(:revision_create_request) do
        {
          revision: {
            guid: revision.guid
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      it 'logs the required fields when a deployment is created' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-deployment' => {
              'api-version' => 'v3',
              'strategy' => 'canary',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json))

          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body
        end
      end

      it 'logs the roll back app request' do
        app_model.update(revisions_enabled: true)
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'rolled-back-app' => {
              'api-version' => 'v3',
              'strategy' => 'canary',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(user.guid),
              'revision-id' => OpenSSL::Digest::SHA256.hexdigest(revision.guid)
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).twice
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(Oj.dump(expected_json)).at_most(:once)

          post '/v3/deployments', revision_create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body
        end
      end
    end

    context 'strategy' do
      let(:create_request) do
        {
          strategy: strategy,
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      context 'when no strategy is provided' do
        let(:user) { make_developer_for_space(space) }
        let(:create_request) do
          {
            relationships: {
              app: {
                data: {
                  guid: app_model.guid
                }
              }
            }
          }
        end

        it 'creates a deployment with strategy "rolling"' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201)

          deployment = VCAP::CloudController::DeploymentModel.last

          expect(parsed_response).to be_a_response_like({
                                                          'guid' => deployment.guid,
                                                          'status' => {
                                                            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                            'details' => {
                                                              'last_successful_healthcheck' => iso8601,
                                                              'last_status_change' => iso8601
                                                            }
                                                          },
                                                          'strategy' => 'rolling',
                                                          'droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'revision' => {
                                                            'guid' => app_model.latest_revision.guid,
                                                            'version' => app_model.latest_revision.version
                                                          },
                                                          'previous_droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'new_processes' => [{
                                                            'guid' => deployment.deploying_web_process.guid,
                                                            'type' => deployment.deploying_web_process.type
                                                          }],
                                                          'created_at' => iso8601,
                                                          'updated_at' => iso8601,
                                                          'metadata' => metadata,
                                                          'relationships' => {
                                                            'app' => {
                                                              'data' => {
                                                                'guid' => app_model.guid
                                                              }
                                                            }
                                                          },
                                                          'links' => {
                                                            'self' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                            },
                                                            'app' => {
                                                              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                            },
                                                            'cancel' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                              'method' => 'POST'
                                                            }
                                                          }
                                                        })
        end
      end

      context 'when strategy "rolling" is provided' do
        let(:strategy) { 'rolling' }
        let(:user) { make_developer_for_space(space) }

        it 'creates a deployment with strategy "rolling" when "strategy":"rolling" is provided' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body

          deployment = VCAP::CloudController::DeploymentModel.last

          expect(parsed_response).to be_a_response_like({
                                                          'guid' => deployment.guid,
                                                          'status' => {
                                                            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                            'details' => {
                                                              'last_successful_healthcheck' => iso8601,
                                                              'last_status_change' => iso8601
                                                            }
                                                          },
                                                          'strategy' => 'rolling',
                                                          'droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'revision' => {
                                                            'guid' => app_model.latest_revision.guid,
                                                            'version' => app_model.latest_revision.version
                                                          },
                                                          'previous_droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'new_processes' => [{
                                                            'guid' => deployment.deploying_web_process.guid,
                                                            'type' => deployment.deploying_web_process.type
                                                          }],
                                                          'created_at' => iso8601,
                                                          'updated_at' => iso8601,
                                                          'metadata' => metadata,
                                                          'relationships' => {
                                                            'app' => {
                                                              'data' => {
                                                                'guid' => app_model.guid
                                                              }
                                                            }
                                                          },
                                                          'links' => {
                                                            'self' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                            },
                                                            'app' => {
                                                              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                            },
                                                            'cancel' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                              'method' => 'POST'
                                                            }
                                                          }
                                                        })
        end
      end

      context 'when strategy "canary" is provided' do
        let(:strategy) { 'canary' }
        let(:user) { make_developer_for_space(space) }

        it 'creates a deployment with strategy "canary" when "strategy":"canary" is provided' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body

          deployment = VCAP::CloudController::DeploymentModel.last

          expect(parsed_response).to be_a_response_like({
                                                          'guid' => deployment.guid,
                                                          'status' => {
                                                            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                            'details' => {
                                                              'last_successful_healthcheck' => iso8601,
                                                              'last_status_change' => iso8601
                                                            }
                                                          },
                                                          'strategy' => 'canary',
                                                          'droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'revision' => {
                                                            'guid' => app_model.latest_revision.guid,
                                                            'version' => app_model.latest_revision.version
                                                          },
                                                          'previous_droplet' => {
                                                            'guid' => droplet.guid
                                                          },
                                                          'new_processes' => [{
                                                            'guid' => deployment.deploying_web_process.guid,
                                                            'type' => deployment.deploying_web_process.type
                                                          }],
                                                          'created_at' => iso8601,
                                                          'updated_at' => iso8601,
                                                          'metadata' => metadata,
                                                          'relationships' => {
                                                            'app' => {
                                                              'data' => {
                                                                'guid' => app_model.guid
                                                              }
                                                            }
                                                          },
                                                          'links' => {
                                                            'self' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                            },
                                                            'app' => {
                                                              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                            },
                                                            'cancel' => {
                                                              'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                              'method' => 'POST'
                                                            }
                                                          }
                                                        })
        end
      end

      context 'when a strategy other than "rolling" is provided' do
        let(:strategy) { 'potato' }

        it 'returns a 422 and error' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(422)

          parsed_response = Oj.load(last_response.body)
          expect(parsed_response['errors'][0]['detail']).to match("Strategy 'potato' is not a supported deployment strategy")
        end
      end
    end

    context 'validation failures' do
      let(:user) { make_developer_for_space(space) }
      let(:smol_quota) { VCAP::CloudController::QuotaDefinition.make(memory_limit: 1) }
      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          }
        }
      end

      before do
        org.quota_definition = smol_quota
        org.save
      end

      it 'returns a 422 when a quota is violated' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(422)

        expect(parsed_response['errors'][0]['detail']).to match('memory quota_exceeded')
      end
    end
  end

  describe 'PATCH /v3/deployments/:guid' do
    let(:user) { make_developer_for_space(space) }
    let(:deployment) do
      VCAP::CloudController::DeploymentModel.make(
        app: app_model,
        droplet: droplet
      )
    end
    let(:update_request) do
      {
        metadata: {
          labels: {
            freaky: 'thursday'
          },
          annotations: {
            quality: 'p sus'
          }
        }
      }.to_json
    end

    it 'updates the deployment with metadata' do
      patch "/v3/deployments/#{deployment.guid}", update_request, user_header
      expect(last_response.status).to eq(200)

      parsed_response = Oj.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
                                                      'guid' => deployment.guid,
                                                      'status' => {
                                                        'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                        'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                        'details' => {
                                                          'last_successful_healthcheck' => iso8601,
                                                          'last_status_change' => iso8601
                                                        }
                                                      },
                                                      'strategy' => 'rolling',
                                                      'droplet' => {
                                                        'guid' => droplet.guid
                                                      },
                                                      'revision' => nil,
                                                      'previous_droplet' => {
                                                        'guid' => nil
                                                      },
                                                      'new_processes' => [],
                                                      'metadata' => {
                                                        'labels' => { 'freaky' => 'thursday' },
                                                        'annotations' => { 'quality' => 'p sus' }
                                                      },
                                                      'created_at' => iso8601,
                                                      'updated_at' => iso8601,
                                                      'relationships' => {
                                                        'app' => {
                                                          'data' => {
                                                            'guid' => app_model.guid
                                                          }
                                                        }
                                                      },
                                                      'links' => {
                                                        'self' => {
                                                          'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                        },
                                                        'app' => {
                                                          'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                        },
                                                        'cancel' => {
                                                          'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                          'method' => 'POST'
                                                        }
                                                      }
                                                    })
    end

    context 'permissions' do
      before do
        space.remove_developer(user)
      end

      let(:api_call) { ->(user_headers) { patch "/v3/deployments/#{deployment.guid}", update_request, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
        h['admin'] = { code: 200 }
        h['space_developer'] = { code: 200 }
        %w[org_auditor org_billing_manager no_role].each { |r| h[r] = { code: 404 } }
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
  end

  describe 'GET /v3/deployments/:guid' do
    let(:api_call) { ->(user_headers) { get "/v3/deployments/#{deployment.guid}", nil, user_headers } }
    let(:old_droplet) { VCAP::CloudController::DropletModel.make }
    let(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app_model,
        droplet: droplet,
        previous_droplet: old_droplet
      )
    end
    let(:expected_response) do
      {
        'guid' => deployment.guid,
        'status' => {
          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
          'details' => {
            'last_successful_healthcheck' => iso8601,
            'last_status_change' => iso8601
          }
        },
        'droplet' => {
          'guid' => droplet.guid
        },
        'revision' => nil,
        'previous_droplet' => {
          'guid' => old_droplet.guid
        },
        'new_processes' => [{
          'guid' => deployment.deploying_web_process.guid,
          'type' => deployment.deploying_web_process.type
        }],
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'metadata' => metadata,
        'strategy' => 'rolling',
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => app_model.guid
            }
          }
        },
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          },
          'cancel' => {
            'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
            'method' => 'POST'
          }
        }
      }
    end
    let(:expected_codes_and_responses) do
      h = Hash.new(code: 200, response_object: expected_response)
      h['org_auditor'] = h['org_billing_manager'] = h['no_role'] = { code: 404 }
      h
    end

    context 'PAUSED deployment' do
      let(:user) { make_developer_for_space(space) }
      let(:deployment) do
        VCAP::CloudController::DeploymentModelTestFactory.make(
          app: app_model,
          droplet: droplet,
          previous_droplet: old_droplet,
          strategy: 'canary',
          state: VCAP::CloudController::DeploymentModel::PAUSED_STATE,
          status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
          status_reason: VCAP::CloudController::DeploymentModel::PAUSED_STATUS_REASON
        )
      end

      it 'includes the continue action in the links' do
        get "/v3/deployments/#{deployment.guid}", nil, user_header
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['links']['continue']).to eq({
                                                             'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/continue",
                                                             'method' => 'POST'
                                                           })
      end

      it 'includes the cancel action in the links' do
        get "/v3/deployments/#{deployment.guid}", nil, user_header
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['links']['cancel']).to eq({
                                                           'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                           'method' => 'POST'
                                                         })
      end
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
  end

  describe 'GET /v3/deployments/' do
    let(:user) {  VCAP::CloudController::User.make }
    let(:space) { app_model.space }
    let(:app_model) { droplet.app }
    let(:droplet) { VCAP::CloudController::DropletModel.make(guid: 'droplet1') }
    let!(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app_model,
        droplet: app_model.droplet,
        previous_droplet: app_model.droplet,
        status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
        state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
        status_reason: VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON
      )
    end

    context 'with an admin who can see all deployments' do
      let(:admin_user_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

      let(:droplet2) { VCAP::CloudController::DropletModel.make(guid: 'droplet2') }
      let(:droplet3) { VCAP::CloudController::DropletModel.make(guid: 'droplet3') }
      let(:droplet4) { VCAP::CloudController::DropletModel.make(guid: 'droplet4') }
      let(:droplet5) { VCAP::CloudController::DropletModel.make(guid: 'droplet5') }
      let(:app2) { droplet2.app }
      let(:app3) { droplet3.app }
      let(:app4) { droplet4.app }
      let(:app5) { droplet5.app }

      before do
        app2.update(space:)
        app3.update(space:)
        app4.update(space:)
        app5.update(space:)
      end

      let!(:deployment2) do
        VCAP::CloudController::DeploymentModelTestFactory.make(app: app2, droplet: droplet2,
                                                               previous_droplet: droplet2,
                                                               status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                               state: VCAP::CloudController::DeploymentModel::CANCELING_STATE,
                                                               status_reason: VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON)
      end

      let!(:deployment3) do
        VCAP::CloudController::DeploymentModelTestFactory.make(app: app3, droplet: droplet3,
                                                               previous_droplet: droplet3,
                                                               status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                                               state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
                                                               status_reason: VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON)
      end

      let!(:deployment4) do
        VCAP::CloudController::DeploymentModelTestFactory.make(app: app4, droplet: droplet4,
                                                               previous_droplet: droplet4,
                                                               status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                                               state: VCAP::CloudController::DeploymentModel::CANCELED_STATE,
                                                               status_reason: VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON)
      end

      let!(:deployment5) do
        VCAP::CloudController::DeploymentModelTestFactory.make(app: app5, droplet: droplet5,
                                                               previous_droplet: droplet5,
                                                               status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                                               state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
                                                               status_reason: VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON)
      end

      let!(:deployment6) do
        VCAP::CloudController::DeploymentModelTestFactory.make(app: app5, droplet: droplet5,
                                                               previous_droplet: droplet5,
                                                               strategy: 'canary',
                                                               status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                               state: VCAP::CloudController::DeploymentModel::DEPLOYING_STATE,
                                                               status_reason: VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)
      end

      # TODO: add pause states and any other canary related states

      def json_for_deployment(deployment, app_model, droplet, status_value, status_reason, cancel_link=true)
        {
          guid: deployment.guid,
          status: {
            value: status_value,
            reason: status_reason,
            details: {
              last_successful_healthcheck: iso8601,
              last_status_change: iso8601
            }
          },
          strategy: deployment.strategy,
          droplet: {
            guid: droplet.guid
          },
          revision: nil,
          # previous_droplet: { guid: nil },
          previous_droplet: {
            guid: droplet.guid
          },
          new_processes: [{
            guid: deployment.deploying_web_process.guid,
            type: deployment.deploying_web_process.type
          }],
          created_at: iso8601,
          updated_at: iso8601,
          metadata: {
            labels: {},
            annotations: {}
          },
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            }
          },
          links: {
            self: {
              href: "#{link_prefix}/v3/deployments/#{deployment.guid}"
            },
            app: {
              href: "#{link_prefix}/v3/apps/#{app_model.guid}"
            }
          }
        }.tap do |json|
          if cancel_link
            json[:links][:cancel] = {
              href: "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
              method: 'POST'
            }
          end
        end
      end

      it 'lists all deployments' do
        get '/v3/deployments?per_page=2', nil, admin_user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to match_json_response({
                                                         pagination: {
                                                           total_results: 6,
                                                           total_pages: 3,
                                                           first: {
                                                             href: "#{link_prefix}/v3/deployments?page=1&per_page=2"
                                                           },
                                                           last: {
                                                             href: "#{link_prefix}/v3/deployments?page=3&per_page=2"
                                                           },
                                                           next: {
                                                             href: "#{link_prefix}/v3/deployments?page=2&per_page=2"
                                                           },
                                                           previous: nil
                                                         },
                                                         resources: [
                                                           json_for_deployment(deployment, app_model, droplet,
                                                                               VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                                               VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON),
                                                           json_for_deployment(deployment2, app2, droplet2,
                                                                               VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                                               VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON)
                                                         ]
                                                       })
      end

      context 'when filtering' do
        let(:api_call) { ->(user_headers) { get endpoint, nil, user_headers } }

        describe 'when filtering by status_value' do
          let(:url) { '/v3/deployments' }
          let(:query) { 'status_values=FINALIZED' }
          let(:endpoint) { "#{url}?#{query}" }
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                json_for_deployment(deployment3, app3, droplet3,
                                    VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON,
                                    false),
                json_for_deployment(deployment4, app4, droplet4,
                                    VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON,
                                    false),
                json_for_deployment(deployment5, app5, droplet5,
                                    VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON,
                                    false)
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

          context 'pagination' do
            let(:pagination_hsh) do
              {
                'total_results' => 3,
                'total_pages' => 1,
                'first' => { 'href' => "#{link_prefix}#{url}?page=1&per_page=50&#{query}" },
                'last' => { 'href' => "#{link_prefix}#{url}?page=1&per_page=50&#{query}" },
                'next' => nil,
                'previous' => nil
              }
            end

            it 'paginates the results' do
              get endpoint, nil, admin_header
              expect(pagination_hsh).to eq(parsed_response['pagination'])
            end
          end
        end

        describe 'when filtering by status_reason' do
          let(:url) { '/v3/deployments' }
          let(:query) { 'status_reasons=SUPERSEDED,DEPLOYED' }
          let(:endpoint) { "#{url}?#{query}" }
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                json_for_deployment(deployment3, app3, droplet3,
                                    VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON,
                                    false),
                json_for_deployment(deployment5, app5, droplet5,
                                    VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON,
                                    false)
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

          context 'pagination' do
            let(:pagination_hsh) do
              {
                'total_results' => 2,
                'total_pages' => 1,
                'first' => { 'href' => "#{link_prefix}#{url}?page=1&per_page=50&#{query.gsub(',', '%2C')}" },
                'last' => { 'href' => "#{link_prefix}#{url}?page=1&per_page=50&#{query.gsub(',', '%2C')}" },
                'next' => nil,
                'previous' => nil
              }
            end

            it 'paginates the results' do
              get endpoint, nil, admin_header
              expect(pagination_hsh).to eq(parsed_response['pagination'])
            end
          end
        end

        describe 'when filtering by state' do
          let(:url) { '/v3/deployments' }
          let(:query) { 'states=DEPLOYING' }
          let(:endpoint) { "#{url}?#{query}" }
          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_objects: [
                json_for_deployment(deployment, app_model, droplet,
                                    VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON),
                json_for_deployment(deployment6, app5, droplet5,
                                    VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                    VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h
          end

          it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

          context 'pagination' do
            let(:pagination_hsh) do
              {
                total_results: 2,
                total_pages: 1,
                first: { href: "#{link_prefix}#{url}?page=1&per_page=50&#{query.gsub(',', '%2C')}" },
                last: { href: "#{link_prefix}#{url}?page=1&per_page=50&#{query.gsub(',', '%2C')}" },
                next: nil,
                previous: nil
              }
            end

            it 'paginates the results' do
              get endpoint, nil, admin_header

              expect(parsed_response['pagination']).to match_json_response(pagination_hsh)
            end
          end
        end

        it 'returns a list of label filtered deployments' do
          VCAP::CloudController::DeploymentLabelModel.make(
            key_name: 'release',
            value: 'stable',
            resource_guid: deployment2.guid
          )
          VCAP::CloudController::DeploymentLabelModel.make(
            key_name: 'release',
            value: 'unstable',
            resource_guid: deployment3.guid
          )

          get '/v3/deployments?label_selector=release=stable', nil, admin_user_header
          expect(last_response.status).to eq(200)

          expect(parsed_response['resources']).to have(1).items
          expect(parsed_response['resources'][0]['guid']).to eq(deployment2.guid)
        end
      end
    end

    context 'when there are other spaces the developer cannot see' do
      let(:user) { make_developer_for_space(space) }
      let(:another_app) { another_droplet.app }
      let(:another_droplet) { VCAP::CloudController::DropletModel.make }
      let!(:another_space) { another_app.space }
      let!(:another_deployment) { VCAP::CloudController::DeploymentModelTestFactory.make(app: another_app, droplet: another_droplet) }

      let(:user_header) { headers_for(user) }

      it_behaves_like 'list query endpoint' do
        let(:request) { 'v3/deployments' }
        let(:message) { VCAP::CloudController::DeploymentsListMessage }
        let(:params) do
          {
            page: '2',
            per_page: '10',
            order_by: 'updated_at',
            states: 'foo',
            status_values: 'foo',
            status_reasons: 'foo',
            app_guids: '123',
            label_selector: 'bar',
            guids: 'foo,bar',
            created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 }
          }
        end
      end

      it 'does not include the deployments in the other space' do
        get '/v3/deployments', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
                                                        'pagination' => {
                                                          'total_results' => 1,
                                                          'total_pages' => 1,
                                                          'first' => {
                                                            'href' => "#{link_prefix}/v3/deployments?page=1&per_page=50"
                                                          },
                                                          'last' => {
                                                            'href' => "#{link_prefix}/v3/deployments?page=1&per_page=50"
                                                          },
                                                          'next' => nil,
                                                          'previous' => nil
                                                        },
                                                        'resources' => [
                                                          {
                                                            'guid' => deployment.guid,
                                                            'status' => {
                                                              'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
                                                              'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
                                                              'details' => {
                                                                'last_successful_healthcheck' => iso8601,
                                                                'last_status_change' => iso8601
                                                              }
                                                            },
                                                            'strategy' => 'rolling',
                                                            'droplet' => {
                                                              'guid' => droplet.guid
                                                            },
                                                            'revision' => nil,
                                                            'previous_droplet' => {
                                                              'guid' => droplet.guid
                                                            },
                                                            'new_processes' => [{
                                                              'guid' => deployment.deploying_web_process.guid,
                                                              'type' => deployment.deploying_web_process.type
                                                            }],
                                                            'created_at' => iso8601,
                                                            'updated_at' => iso8601,
                                                            'metadata' => metadata,
                                                            'relationships' => {
                                                              'app' => {
                                                                'data' => {
                                                                  'guid' => app_model.guid
                                                                }
                                                              }
                                                            },
                                                            'links' => {
                                                              'self' => {
                                                                'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}"
                                                              },
                                                              'app' => {
                                                                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
                                                              },
                                                              'cancel' => {
                                                                'href' => "#{link_prefix}/v3/deployments/#{deployment.guid}/actions/cancel",
                                                                'method' => 'POST'
                                                              }
                                                            }
                                                          }
                                                        ]
                                                      })
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::DeploymentModel }
      let(:api_call) do
        ->(headers, filters) { get "/v3/deployments?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end
  end

  describe 'POST /v3/deployments/:guid/actions/cancel' do
    let(:old_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { 'web' => 'run' }) }
    let(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app_model,
        droplet: droplet,
        previous_droplet: old_droplet
      )
    end

    context 'with a running deployment' do
      let(:api_call) { ->(user_headers) { post "/v3/deployments/#{deployment.guid}/actions/cancel", {}.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = h['space_developer'] = h['space_supporter'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 404 } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the deployment is running and has a previous droplet' do
      let(:user) { make_developer_for_space(space) }

      it 'changes the deployment status_value CANCELING and rolls the droplet back' do
        post "/v3/deployments/#{deployment.guid}/actions/cancel", {}.to_json, user_header
        expect(last_response.status).to eq(200), last_response.body

        expect(last_response.body).to be_empty
        deployment.reload
        expect(deployment.status_value).to eq(VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE)
        expect(deployment.status_reason).to eq(VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON)

        expect(app_model.reload.droplet).to eq(old_droplet)

        require 'cloud_controller/deployment_updater/scheduler'
        VCAP::CloudController::DeploymentUpdater::Updater.new(deployment, Steno.logger('blah')).cancel
        deployment.reload
        expect(deployment.status_value).to eq(VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE)
        expect(deployment.status_reason).to eq(VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON)
      end
    end
  end

  describe 'POST /v3/deployments/:guid/actions/continue' do
    let(:state) {}
    let(:deployment) do
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app_model,
        droplet: droplet,
        state: state
      )
    end

    context 'when the deployment is in paused state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::PAUSED_STATE }

      it 'transitions the deployment from paused to deploying' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(200), last_response.body
        expect(last_response.body).to be_empty

        deployment.reload
        expect(deployment.state).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATE)
        expect(deployment.status_reason).to eq(VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON)
      end
    end

    context 'when the deployment is in a prepaused state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::PREPAUSED_STATE }

      it 'returns 422 with an error' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(422), last_response.body
      end
    end

    context 'when the deployment is in a deploying state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }

      it 'returns 422 with an error' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(422), last_response.body
      end
    end

    context 'when the deployment is in a canceling state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::CANCELING_STATE }

      it 'returns 422 with an error' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(422), last_response.body
      end
    end

    context 'when the deployment is in a deployed state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::DEPLOYED_STATE }

      it 'returns 422 with an error' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(422), last_response.body
      end
    end

    context 'when the deployment is in a canceled state' do
      let(:user) { make_developer_for_space(space) }
      let(:state) { VCAP::CloudController::DeploymentModel::CANCELED_STATE }

      it 'returns 422 with an error' do
        post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_header
        expect(last_response.status).to eq(422), last_response.body
      end
    end
    # TODO: how much do we want to test here ?
    #
    # context 'when the deployment is not a canary' do
    # note from Seth: I don't think we need this case, what if we add the `pause` action :)
    #   let(:state) { VCAP::CloudController::DeploymentModel::PREPAUSED_STATE }

    # end

    # context 'when the deployment is superseeded' do
    # end

    # TODO: understand this
    context 'with a running deployment' do
      let(:state) { VCAP::CloudController::DeploymentModel::PAUSED_STATE }
      let(:api_call) { ->(user_headers) { post "/v3/deployments/#{deployment.guid}/actions/continue", {}.to_json, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = h['space_developer'] = h['space_supporter'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 404 } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end
end
