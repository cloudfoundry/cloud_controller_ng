require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Stacks Request' do
  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy }
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    it 'returns 200 OK' do
      get '/v3/stacks', nil, headers
      expect(last_response.status).to eq(200)
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Stack }
      let(:headers) { admin_headers }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/stacks?#{filters}", nil, headers }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/stacks' }
      let(:message) { VCAP::CloudController::StacksListMessage }
      let(:user_header) { headers }

      let(:params) do
        {
          names: ['foo', 'bar'],
          page:   '2',
          per_page:   '10',
          order_by:   'updated_at',
          label_selector:   'foo,bar',
          guids: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    context 'When stacks exist' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }
      let!(:stack3) { VCAP::CloudController::Stack.make }

      it 'returns a paginated list of stacks' do
        get '/v3/stacks?page=1&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/stacks?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/stacks?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/stacks?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'name' => stack1.name,
                'description' => stack1.description,
                'guid' => stack1.guid,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack1.guid}"
                  }
                }
              },
              {
                'name' => stack2.name,
                'description' => stack2.description,
                'guid' => stack2.guid,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack2.guid}"
                  }
                }
              }
            ]
          }
        )
      end

      it 'returns a list of name filtered stacks' do
        get "/v3/stacks?names=#{stack1.name},#{stack3.name}", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/stacks?names=#{stack1.name}%2C#{stack3.name}&page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/stacks?names=#{stack1.name}%2C#{stack3.name}&page=1&per_page=50"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'name' => stack1.name,
                'description' => stack1.description,
                'guid' => stack1.guid,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack1.guid}"
                  }
                }
              },
              {
                'name' => stack3.name,
                'description' => stack3.description,
                'guid' => stack3.guid,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/stacks/#{stack3.guid}"
                  }
                }
              }
            ]
          }
        )
      end

      context 'when there are labels' do
        let!(:stack1_label) { VCAP::CloudController::StackLabelModel.make(
          key_name: 'release',
          value: 'stable',
          resource_guid: stack1.guid
        )
        }
        let!(:stack2_label) { VCAP::CloudController::StackLabelModel.make(
          key_name: 'release',
          value: 'unstable',
          resource_guid: stack2.guid
        )
        }

        it 'returns a list of label filtered stacks' do
          get '/v3/stacks?label_selector=release=stable', nil, headers

          expect(parsed_response).to be_a_response_like(
            {
              'pagination' => {
                'total_results' => 1,
                'total_pages' => 1,
                'first' => {
                  'href' => "#{link_prefix}/v3/stacks?label_selector=release%3Dstable&page=1&per_page=50"
                },
                'last' => {
                  'href' => "#{link_prefix}/v3/stacks?label_selector=release%3Dstable&page=1&per_page=50"
                },
                'next' => nil,
                'previous' => nil
              },
              'resources' => [
                {
                  'name' => stack1.name,
                  'description' => stack1.description,
                  'guid' => stack1.guid,
                  'metadata' => {
                    'labels' => {
                      'release' => 'stable'
                    },
                    'annotations' => {}
                  },
                  'created_at' => iso8601,
                  'updated_at' => iso8601,
                  'links' => {
                    'self' => {
                      'href' => "#{link_prefix}/v3/stacks/#{stack1.guid}"
                    }
                  },
                },
              ]
            }
          )
        end
      end
    end
  end

  describe 'GET /v3/stacks/:guid' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    let!(:stack) { VCAP::CloudController::Stack.make }

    it 'returns details of the requested stack' do
      get "/v3/stacks/#{stack.guid}", nil, headers
      expect(last_response.status).to eq 200
      expect(parsed_response).to be_a_response_like(
        {
          'name' => stack.name,
          'description' => stack.description,
          'guid' => stack.guid,
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/stacks/#{stack.guid}"
            }
          }
        }
      )
    end
  end

  describe 'GET /v3/stacks/:guid/apps' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let!(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let!(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'bp-name') }
    let!(:space) { make_space_for_user(user) }
    let!(:space2) { VCAP::CloudController::Space.make }
    let!(:app_model1) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
    let!(:app_model2) { VCAP::CloudController::AppModel.make(name: 'name2', space: space2) }
    let!(:app_model3) do
      VCAP::CloudController::AppModel.make(
        :docker,
        name: 'name2')
    end

    before do
      app_model1.buildpack_lifecycle_data.update(stack: stack.name, buildpacks: [buildpack.name])
      app_model2.buildpack_lifecycle_data.update(stack: stack.name, buildpacks: [buildpack.name])
    end

    it 'returns the list of space-visible apps using the given stack' do
      get "/v3/stacks/#{stack.guid}/apps", { per_page: 2 }, headers

      expect(last_response.status).to eq(200), last_response.body
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
            'previous' => nil,
            'next' => nil,
          },
          'resources' => [
            {
              'guid' => app_model1.guid,
              'name' => 'name1',
              'state' => 'STOPPED',
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpacks' => ['bp-name'],
                  'stack' => 'stack-name',
                }
              },
              'relationships' => {
                'space' => {
                  'data' => {
                    'guid' => space.guid
                  }
                }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/tasks" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/features" },
              }
            },
          ]
        }
      )
    end

    context 'as an admin user' do
      let!(:user) { make_user(admin: true) }
      let!(:headers) { admin_headers_for(user) }
      it 'return the list of all apps using the given stack' do
        get "/v3/stacks/#{stack.guid}/apps", { per_page: 2 }, headers

        expect(last_response.status).to eq(200), last_response.body
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'last' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'previous' => nil,
              'next' => nil,
            },
            'resources' => [
              {
                'guid' => app_model1.guid,
                'name' => 'name1',
                'state' => 'STOPPED',
                'lifecycle' => {
                  'type' => 'buildpack',
                  'data' => {
                    'buildpacks' => ['bp-name'],
                    'stack' => 'stack-name',
                  }
                },
                'relationships' => {
                  'space' => {
                    'data' => {
                      'guid' => space.guid
                    }
                  }
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}" },
                  'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/processes" },
                  'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/packages" },
                  'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/environment_variables" },
                  'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                  'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets/current" },
                  'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets" },
                  'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/tasks" },
                  'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/start", 'method' => 'POST' },
                  'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/stop", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/features" },
                }
              },
              {
                'guid' => app_model2.guid,
                'name' => 'name2',
                'state' => 'STOPPED',
                'lifecycle' => {
                  'type' => 'buildpack',
                  'data' => {
                    'buildpacks' => ['bp-name'],
                    'stack' => 'stack-name',
                  }
                },
                'relationships' => {
                  'space' => {
                    'data' => {
                      'guid' => space2.guid
                    }
                  }
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}" },
                  'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/processes" },
                  'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/packages" },
                  'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/environment_variables" },
                  'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space2.guid}" },
                  'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/droplets/current" },
                  'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/droplets" },
                  'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/tasks" },
                  'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/start", 'method' => 'POST' },
                  'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/stop", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/features" },
                }
              }
            ]
          }
        )
      end
    end

    context 'user is not logged in' do
      it 'returns 401 when user not logged in' do
        get "/v3/stacks/#{stack.guid}/apps", {}, {} # empty headers indicates logged out

        expect(last_response.status).to eq 401
      end
    end

    context 'when seeking apps for a stack that does not exist' do
      it '404s' do
        get '/v3/stacks/hot_garbage/apps', {}, headers
        expect(last_response.status).to eq 404
        expect(last_response.body).to include('ResourceNotFound')
      end
    end

    context 'when the params are invalid' do
      it '400s' do
        get "/v3/stacks/#{stack.guid}/apps", { per_pae: 2 }, headers

        expect(last_response.status).to eq(400), last_response.body
      end
    end
  end

  describe 'POST /v3/stacks' do
    let(:user) { make_user(admin: true) }
    let(:request_body) do
      {
        name: 'the-name',
        description: 'the-description',
        metadata: {
          labels: {
            potato: 'yam',
          },
          annotations: {
            potato: 'idaho',
          }
        }
      }.to_json
    end
    let(:headers) { admin_headers_for(user) }

    it 'creates a new stack' do
      expect {
        post '/v3/stacks', request_body, headers
      }.to change {
        VCAP::CloudController::Stack.count
      }.by 1

      created_stack = VCAP::CloudController::Stack.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'name' => 'the-name',
          'description' => 'the-description',
          'metadata' => {
            'labels' => {
              'potato' => 'yam'
            },
            'annotations' => {
              'potato' => 'idaho'
            },
          },
          'guid' => created_stack.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/stacks/#{created_stack.guid}"
            }
          }
        }
      )
    end

    context 'when there is a model validation failure' do
      let(:name) { 'the-name' }

      before do
        VCAP::CloudController::Stack.make name: name
      end

      it 'responds with 422' do
        post '/v3/stacks', request_body, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Name must be unique')
      end
    end
  end

  describe 'PATCH /v3/stacks/:guid' do
    let(:user) { make_user(admin: true) }
    let(:stack) { VCAP::CloudController::Stack.make }
    let(:request_body) do
      {
        metadata: {
          labels: {
            potato: 'yam'
          },
          annotations: {
            potato: 'idaho'
          }
        }
      }.to_json
    end
    let(:headers) { admin_headers_for(user) }

    it 'updates the metadata of a new stack' do
      patch "/v3/stacks/#{stack.guid}", request_body, headers

      expect(last_response.status).to eq(200)

      expect(parsed_response).to be_a_response_like(
        {
          'name' => stack.name,
          'description' => stack.description,
          'metadata' => {
            'labels' => {
              'potato' => 'yam'
            },
            'annotations' => {
              'potato' => 'idaho'
            },
          },
          'guid' => stack.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/stacks/#{stack.guid}"
            }
          }
        }
      )
    end
  end

  describe 'DELETE /v3/stacks/:guid' do
    let(:user) { make_user(admin: true) }
    let(:headers) { admin_headers_for(user) }
    let(:stack) { VCAP::CloudController::Stack.make }

    it 'destroys the stack' do
      delete "/v3/stacks/#{stack.guid}", {}, headers

      expect(last_response.status).to eq(204)
      expect(stack).to_not exist
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { stack }
        let(:api_call) do
          -> { delete "/v3/stacks/#{resource.guid}", nil, headers }
        end
      end
    end
  end
end
