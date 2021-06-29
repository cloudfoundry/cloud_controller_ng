require 'spec_helper'
require 'request_spec_shared_examples'

SPACE_APPLICATION_SUPPORTER = %w[space_application_supporter].freeze
COMPLETE_PERMISSIONS = (ALL_PERMISSIONS + SPACE_APPLICATION_SUPPORTER).freeze

RSpec.describe 'Deployments' do
  let(:user) {  VCAP::CloudController::User.make }
  let(:space) { app_model.space }
  let(:org) { space.organization }
  let(:app_model) { VCAP::CloudController::AppModel.make(desired_state: VCAP::CloudController::ProcessModel::STARTED) }
  let(:droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { web: 'webby' }) }
  let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model) }
  let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }
  let(:metadata) { { 'labels' => {}, 'annotations' => {} } }

  before do
    TestConfig.override(temporary_disable_deployments: false)
    app_model.update(droplet_guid: droplet.guid)
  end

  describe 'POST /v3/deployments' do
    let(:user) { make_developer_for_space(space) }
    context 'when a droplet is not supplied with the request' do
      let(:expected_response) {
        {
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => droplet.guid
          },
          'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
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
        }
      }
      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            },
          }
        }
      end
      let(:deployment) {
        VCAP::CloudController::DeploymentModel.last
      }

      context 'as a SpaceDeveloper' do
        it 'should create a deployment object using the current droplet from the app' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201)

          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end

      context 'as a SpaceApplicationSupporter' do
        let(:user) { make_application_supporter_for_space(space) }

        it 'should create a deployment object using the current droplet from the app' do
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201)

          expect(parsed_response).to be_a_response_like(expected_response)
        end
      end
    end

    context 'when a droplet is supplied with the request' do
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
            },
          }
        }
      end

      it 'creates a deployment object with that droplet' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)
        parsed_response = MultiJson.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last

        expect(parsed_response).to be_a_response_like({
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => other_droplet.guid
          },
          'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
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
            },
          }
        }
      end

      it 'should create a deployment object using the droplet associated with the revision' do
        revision_count = VCAP::CloudController::RevisionModel.count
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201), last_response.body
        expect(VCAP::CloudController::RevisionModel.count).to eq(revision_count + 1)

        parsed_response = MultiJson.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last
        revision = VCAP::CloudController::RevisionModel.last

        expect(parsed_response).to be_a_response_like({
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => other_droplet.guid
          },
          'revision' => {
            'guid' => revision.guid,
            'version' => revision.version,
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
            },
          }
        }
      end

      it 'fails' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(422)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['errors'][0]['detail']).to match('Cannot set both fields')
      end
    end

    context 'when metadata is supplied with the request' do
      let(:metadata) {
        {
          'labels' => {
            release: 'stable',
            'seriouseats.com/potato' => 'mashed',
          },
          'annotations' => {
            potato: 'idaho',
          },
        }
      }

      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              },
            },
          },
          metadata: metadata,
        }
      end

      it 'should create a deployment object with the metadata' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(201)

        deployment = VCAP::CloudController::DeploymentModel.last
        expect(deployment).to have_labels(
          { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
          { prefix: nil, key: 'release', value: 'stable' }
        )
        expect(deployment).to have_annotations(
          { key: 'potato', value: 'idaho' },
        )

        expect(parsed_response).to be_a_response_like({
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => droplet.guid
          },
          'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
          },
          'previous_droplet' => {
            'guid' => droplet.guid
          },
          'new_processes' => [{
            'guid' => deployment.deploying_web_process.guid,
            'type' => deployment.deploying_web_process.type
          }],
          'metadata' => { 'labels' => { 'release' => 'stable', 'seriouseats.com/potato' => 'mashed' }, 'annotations' => { 'potato' => 'idaho' } },
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
            },
          }
        }
      end

      it 'creates a deployment with a reference to the new revision' do
        expect {
          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body
        }.to change { VCAP::CloudController::RevisionModel.count }.by(1)

        deployment = VCAP::CloudController::DeploymentModel.last
        revision = VCAP::CloudController::RevisionModel.last
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => other_droplet.guid
          },
          'revision' => {
            'guid' => revision.guid,
            'version' => revision.version,
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
            },
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
        parsed_response = MultiJson.load(last_response.body)

        deployment = VCAP::CloudController::DeploymentModel.last

        expect(parsed_response).to be_a_response_like({
          'guid' => deployment.guid,
          'status' => {
            'value' => VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
            'reason' => VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON,
            'details' => {
              'last_successful_healthcheck' => iso8601
            }
          },
          'strategy' => 'rolling',
          'droplet' => {
            'guid' => other_droplet.guid
          },
          'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
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

      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            },
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
            },
          }
        }
      end

      it 'should log the required fields when a deployment is created' do
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-deployment' => {
              'api-version' => 'v3',
              'strategy' => 'rolling',
              'app-id' => Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => Digest::SHA256.hexdigest(user.guid),
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(JSON.generate(expected_json))

          post '/v3/deployments', create_request.to_json, user_header
          expect(last_response.status).to eq(201), last_response.body
        end
      end
      it 'should log the roll back app request' do
        app_model.update(revisions_enabled: true)
        Timecop.freeze do
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'rolled-back-app' => {
              'api-version' => 'v3',
              'strategy' => 'rolling',
              'app-id' => Digest::SHA256.hexdigest(app_model.guid),
              'user-id' => Digest::SHA256.hexdigest(user.guid),
              'revision-id' => Digest::SHA256.hexdigest(revision.guid),
            }
          }
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).twice
          expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(JSON.generate(expected_json)).at_most(:once)

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
            },
          }
        }
      end

      context 'when no strategy is provided' do
        let(:create_request) do
          {
            relationships: {
              app: {
                data: {
                  guid: app_model.guid
                }
              },
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
                'last_successful_healthcheck' => iso8601
              }
            },
            'strategy' => 'rolling',
            'droplet' => {
              'guid' => droplet.guid
            },
            'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
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
                'last_successful_healthcheck' => iso8601
              }
            },
            'strategy' => 'rolling',
            'droplet' => {
              'guid' => droplet.guid
            },
            'revision' => {
            'guid' => app_model.latest_revision.guid,
            'version' => app_model.latest_revision.version,
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

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['errors'][0]['detail']).to match("Strategy 'potato' is not a supported deployment strategy")
        end
      end
    end

    context 'validation failures' do
      let(:smol_quota) { VCAP::CloudController::QuotaDefinition.make(memory_limit: 1) }
      let(:create_request) do
        {
          relationships: {
            app: {
              data: {
                guid: app_model.guid
              }
            },
          }
        }
      end

      before do
        org.quota_definition = smol_quota
        org.save
      end

      it 'should return a 422 when a quota is violated' do
        post '/v3/deployments', create_request.to_json, user_header
        expect(last_response.status).to eq(422)

        expect(parsed_response['errors'][0]['detail']).to match('memory quota_exceeded')
      end
    end
  end

  describe 'PATCH /v3/deployments' do
    let(:user) { make_developer_for_space(space) }
    let(:deployment) {
      VCAP::CloudController::DeploymentModel.make(
        app: app_model,
        droplet: droplet,
      )
    }
    let(:update_request) do
      {
        metadata: {
          labels: {
            freaky: 'thursday'
          },
          annotations: {
            quality: 'p sus'
          }
        },
      }.to_json
    end
    let(:expected_response) do
      {
        'guid' => deployment.guid,
        'status' => {
          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
          'details' => {
            'last_successful_healthcheck' => iso8601
          }
        },
        'strategy' => 'rolling',
        'droplet' => {
          'guid' => droplet.guid,
        },
        'revision' => nil,
        'previous_droplet' => {
          'guid' => nil,
        },
        'new_processes' => [],
        'metadata' => {
          'labels' => { 'freaky' => 'thursday' },
          'annotations' => { 'quality' => 'p sus' },
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
      }
    end

    context 'as a SpaceDeveloper' do
      it 'updates the deployment with metadata' do
        patch "/v3/deployments/#{deployment.guid}", update_request, user_header
        expect(last_response.status).to eq(200)
  
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    context 'as a SpaceApplicationSupporter' do
      let(:user) { make_application_supporter_for_space(space) }

    end
  end

  describe 'GET /v3/deployments/:guid' do
    let(:old_droplet) { VCAP::CloudController::DropletModel.make }
    let(:deployment) {
      VCAP::CloudController::DeploymentModelTestFactory.make(
        app: app_model,
        droplet: droplet,
        previous_droplet: old_droplet
      )
    }
    let(:api_call) { lambda { |user_headers| get "/v3/deployments/#{deployment.guid}", nil, user_headers } }
    let(:expected_response) {
      {
        'guid' => deployment.guid,
        'status' => {
          'value' => VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
          'reason' => VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON,
          'details' => {
            'last_successful_healthcheck' => iso8601
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
    }

    let(:expected_codes_and_responses) do
      h = Hash.new(code: 200, response_object: expected_response)
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
      h['no_role'] = { code: 404 }
      h
    end

    it_behaves_like 'permissions for single object endpoint', COMPLETE_PERMISSIONS
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
      let(:admin_user_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

      let(:droplet2) { VCAP::CloudController::DropletModel.make(guid: 'droplet2') }
      let(:droplet3) { VCAP::CloudController::DropletModel.make(guid: 'droplet3') }
      let(:droplet4) { VCAP::CloudController::DropletModel.make(guid: 'droplet4') }
      let(:droplet5) { VCAP::CloudController::DropletModel.make(guid: 'droplet5') }
      let(:app2) { droplet2.app }
      let(:app3) { droplet3.app }
      let(:app4) { droplet4.app }
      let(:app5) { droplet5.app }

      before do
        app2.update(space: space)
        app3.update(space: space)
        app4.update(space: space)
        app5.update(space: space)
      end

      let!(:deployment2) { VCAP::CloudController::DeploymentModelTestFactory.make(app: app2, droplet: droplet2,
        previous_droplet: droplet2,
        status_value: VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE,
        state: VCAP::CloudController::DeploymentModel::CANCELING_STATE,
        status_reason: VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON)
      }

      let!(:deployment3) { VCAP::CloudController::DeploymentModelTestFactory.make(app: app3, droplet: droplet3,
        previous_droplet: droplet3,
        status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
        state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
        status_reason: VCAP::CloudController::DeploymentModel::DEPLOYED_STATUS_REASON)
      }

      let!(:deployment4) { VCAP::CloudController::DeploymentModelTestFactory.make(app: app4, droplet: droplet4,
        previous_droplet: droplet4,
        status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
        state: VCAP::CloudController::DeploymentModel::CANCELED_STATE,
        status_reason: VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON)
      }

      let!(:deployment5) { VCAP::CloudController::DeploymentModelTestFactory.make(app: app5, droplet: droplet5,
        previous_droplet: droplet5,
        status_value: VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
        state: VCAP::CloudController::DeploymentModel::DEPLOYED_STATE,
        status_reason: VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON)
      }

      def json_for_deployment(deployment, app_model, droplet, status_value, status_reason, cancel_link=true)
        {
          guid: deployment.guid,
          status: {
            value: status_value,
            reason: status_reason,
            details: {
              last_successful_healthcheck: iso8601
            }
          },
          strategy: 'rolling',
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
            annotations: {},
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

      it 'should list all deployments' do
        get '/v3/deployments?per_page=2', nil, admin_user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to match_json_response({
          pagination: {
            total_results: 5,
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
              VCAP::CloudController::DeploymentModel::CANCELING_STATUS_REASON),
          ]
        })
      end

      context 'when filtering' do
        let(:api_call) { lambda { |user_headers| get endpoint, nil, user_headers } }

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
                false
                ),
                json_for_deployment(deployment4, app4, droplet4,
                  VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                  VCAP::CloudController::DeploymentModel::CANCELED_STATUS_REASON,
                false
                ),
                json_for_deployment(deployment5, app5, droplet5,
                  VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                  VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON,
                false
                ),
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS

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
                  false
                ),
                json_for_deployment(deployment5, app5, droplet5,
                  VCAP::CloudController::DeploymentModel::FINALIZED_STATUS_VALUE,
                  VCAP::CloudController::DeploymentModel::SUPERSEDED_STATUS_REASON,
                  false
                )
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS

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
              ]
            )
            h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = {
              code: 200,
              response_objects: []
            }
            h.freeze
          end

          it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS

          context 'pagination' do
            let(:pagination_hsh) do
              {
                total_results: 1,
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
            page:   '2',
            per_page:   '10',
            order_by:   'updated_at',
            states:   'foo',
            status_values:   'foo',
            status_reasons:   'foo',
            app_guids:   '123',
            label_selector:   'bar',
            guids: 'foo,bar',
            created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 },
          }
        end
      end

      it 'should not include the deployments in the other space' do
        get '/v3/deployments', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
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
                  'last_successful_healthcheck' => iso8601
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
            },
          ]
        })
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::DeploymentModel }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/deployments?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    it_behaves_like 'permissions for list endpoint', COMPLETE_PERMISSIONS do
      let(:api_call) do
        lambda { |headers| get "/v3/deployments", nil, headers }
      end
      let(:deployments_response_object) do
        {
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
                  'last_successful_healthcheck' => iso8601
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
            },
          ]
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_object: deployments_response_object)
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end
    end
  end

  describe 'POST /v3/deployments/:guid/actions/cancel' do
    let(:user) { make_developer_for_space(space) }
    context 'when the deployment is running and has a previous droplet' do
      let(:old_droplet) { VCAP::CloudController::DropletModel.make(app: app_model, process_types: { 'web' => 'run' }) }
      let(:deployment) {
        VCAP::CloudController::DeploymentModelTestFactory.make(
          app: app_model,
          droplet: droplet,
          previous_droplet: old_droplet
        )
      }

      context 'as a SpaceDeveloper' do
        it 'succeeds' do
          post "/v3/deployments/#{deployment.guid}/actions/cancel", {}.to_json, user_header
          expect(last_response.status).to eq(200), last_response.body
          expect(last_response.body).to be_empty
        end

        it 'changes the deployment status_value CANCELING and rolls the droplet back' do
          post "/v3/deployments/#{deployment.guid}/actions/cancel", {}.to_json, user_header
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

      context 'as a SpaceApplicationSupporter' do
        let(:user) { make_application_supporter_for_space(space) }

        it 'succeeds' do
          post "/v3/deployments/#{deployment.guid}/actions/cancel", {}.to_json, user_header
          expect(last_response.status).to eq(200), last_response.body
          expect(last_response.body).to be_empty
        end
      end
    end
  end
end
