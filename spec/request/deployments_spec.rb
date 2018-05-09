require 'spec_helper'

RSpec.describe 'Deployments' do
  let(:user) { make_developer_for_space(space) }
  let(:space) { app_model.space }
  let(:app_model) { droplet.app }
  let(:droplet) { VCAP::CloudController::DropletModel.make }
  let!(:process_model) { VCAP::CloudController::ProcessModel.make(app: app_model) }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }

  before do
    app_model.update(droplet_guid: droplet.guid)
  end

  describe 'POST /v3/deployments' do
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

    it 'should create a deployment object' do
      post '/v3/deployments', create_request.to_json, user_header
      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)

      deployment = VCAP::CloudController::DeploymentModel.last

      expect(parsed_response).to be_a_response_like({
        'guid' => deployment.guid,
        'state' => 'DEPLOYING',
        'droplet' => {
          'guid' => droplet.guid
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
          }
        }
      })
    end
  end

  describe 'GET /v3/deployments/:guid' do
    let(:original_droplet) { VCAP::CloudController::DropletModel.make }

    it 'should get and display the deployment' do
      deployment = VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app_model, droplet: original_droplet)

      get "/v3/deployments/#{deployment.guid}", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'guid' => deployment.guid,
        'state' => 'DEPLOYING',
        'droplet' => {
          'guid' => original_droplet.guid
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
          }
        }
      })
    end
  end

  describe 'GET /v3/deployments/' do
    let(:user) { make_developer_for_space(space) }
    let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
    let(:user_email) { Sham.email }
    let(:user_name) { 'some-username' }

    let(:space) { app_model.space }
    let(:app_model) { droplet.app }
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    let!(:deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app_model, droplet: app_model.droplet) }

    context 'with an admin who can see all deployments' do
      let(:admin_user_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

      let(:droplet2) { VCAP::CloudController::DropletModel.make }
      let(:droplet3) { VCAP::CloudController::DropletModel.make }
      let(:droplet4) { VCAP::CloudController::DropletModel.make }
      let(:app2) { droplet2.app }
      let(:app3) { droplet3.app }
      let(:app4) { droplet4.app }
      let!(:deployment2) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app2, droplet: app2.droplet) }
      let!(:deployment3) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app3, droplet: app3.droplet) }
      let!(:deployment4) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: app4, droplet: app4.droplet) }

      it 'should list all deployments' do
        get '/v3/deployments?per_page=2', nil, admin_user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
          'pagination' => {
            'total_results' => 4,
            'total_pages' => 2,
            'first' => {
              'href' => "#{link_prefix}/v3/deployments?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/deployments?page=2&per_page=2"
            },
            'next' => {
              'href' => "#{link_prefix}/v3/deployments?page=2&per_page=2"
            },
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => deployment.guid,
              'state' => 'DEPLOYING',
              'droplet' => {
                'guid' => droplet.guid
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
                }
              }
            },
            {
              'guid' => deployment2.guid,
              'state' => 'DEPLOYING',
              'droplet' => {
                'guid' => droplet2.guid
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'app' => {
                  'data' => {
                    'guid' => app2.guid
                  }
                }
              },
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/deployments/#{deployment2.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app2.guid}"
                }
              }
            },
          ]
        })
      end
    end

    context 'when there are other spaces the developer cannot see' do
      let(:another_app) { another_droplet.app }
      let(:another_droplet) { VCAP::CloudController::DropletModel.make }
      let(:another_space) { another_app.space }
      let!(:another_deployment) { VCAP::CloudController::DeploymentModel.make(state: 'DEPLOYING', app: another_app, droplet: another_droplet) }

      let(:user_header) { headers_for(user) }

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
              'state' => 'DEPLOYING',
              'droplet' => {
                'guid' => droplet.guid
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
                }
              }
            },
          ]
        })
      end
    end
  end
end
