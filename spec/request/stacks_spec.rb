require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Stacks Request' do
  let(:stack_config_file) { File.join(Paths::FIXTURES, 'config/stacks.yml') }
  let(:default_stack_name) { 'default-stack-name' }
  let(:org) { VCAP::CloudController::Organization.make(created_at: 3.days.ago) }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }

  before { VCAP::CloudController::Stack.configure(stack_config_file) }

  describe 'GET /v3/stacks' do
    before { VCAP::CloudController::Stack.dataset.destroy }

    let(:user) { make_user }
    let(:user_header) { headers_for(user) }
    let(:api_call) { ->(user_header) { get '/v3/stacks', nil, user_header } }

    context 'lists all stacks' do
      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS do
        let(:stacks_response_objects) do
          [
            {
              'name' => stack1.name,
              'description' => stack1.description,
              'run_rootfs_image' => stack1.run_rootfs_image,
              'build_rootfs_image' => stack1.build_rootfs_image,
              'guid' => stack1.guid,
              'default' => false,
              'deprecated_at' => nil,
              'locked_at' => nil,
              'disabled_at' => nil,
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
              'run_rootfs_image' => stack2.run_rootfs_image,
              'build_rootfs_image' => stack2.build_rootfs_image,
              'guid' => stack2.guid,
              'default' => true,
              'deprecated_at' => nil,
              'locked_at' => nil,
              'disabled_at' => nil,
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
        end

        let(:expected_codes_and_responses) do
          Hash.new({ code: 200, response_objects: stacks_response_objects }.freeze)
        end
        let!(:stack1) { VCAP::CloudController::Stack.make }
        let!(:stack2) { VCAP::CloudController::Stack.make(name: default_stack_name) }
      end
    end

    context 'lists a subset of stacks' do
      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::Stack }
        let(:headers) { admin_headers }
        let(:api_call) do
          ->(headers, filters) { get "/v3/stacks?#{filters}", nil, headers }
        end
      end

      it_behaves_like 'list query endpoint' do
        let(:request) { 'v3/stacks' }
        let(:message) { VCAP::CloudController::StacksListMessage }
        let(:params) do
          {
            names: %w[foo bar],
            default: true,
            page: '2',
            per_page: '10',
            order_by: 'updated_at',
            label_selector: 'foo,bar',
            guids: 'foo,bar',
            created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 }
          }
        end
        let!(:stack) { VCAP::CloudController::Stack.make(name: default_stack_name) }
      end

      context 'When stacks exist' do
        let!(:stack1) { VCAP::CloudController::Stack.make }
        let!(:stack2) { VCAP::CloudController::Stack.make(name: default_stack_name) }
        let!(:stack3) { VCAP::CloudController::Stack.make }

        it 'returns a paginated list of stacks' do
          get '/v3/stacks?page=1&per_page=2', nil, user_header

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
                  'run_rootfs_image' => stack1.run_rootfs_image,
                  'build_rootfs_image' => stack1.build_rootfs_image,
                  'guid' => stack1.guid,
                  'default' => false,
                  'deprecated_at' => nil,
                  'locked_at' => nil,
                  'disabled_at' => nil,
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
                  'run_rootfs_image' => stack2.run_rootfs_image,
                  'build_rootfs_image' => stack2.build_rootfs_image,
                  'guid' => stack2.guid,
                  'default' => true,
                  'deprecated_at' => nil,
                  'locked_at' => nil,
                  'disabled_at' => nil,
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
          get "/v3/stacks?names=#{stack1.name},#{stack3.name}", nil, user_header

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
                  'run_rootfs_image' => stack1.run_rootfs_image,
                  'build_rootfs_image' => stack1.build_rootfs_image,
                  'guid' => stack1.guid,
                  'default' => false,
                  'deprecated_at' => nil,
                  'locked_at' => nil,
                  'disabled_at' => nil,
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
                  'run_rootfs_image' => stack3.run_rootfs_image,
                  'build_rootfs_image' => stack3.build_rootfs_image,
                  'guid' => stack3.guid,
                  'default' => false,
                  'deprecated_at' => nil,
                  'locked_at' => nil,
                  'disabled_at' => nil,
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

        it 'returns a list of stacks filtered by whether they are default' do
          get '/v3/stacks?default=true', nil, user_header

          expect(parsed_response).to be_a_response_like(
            {
              'pagination' => {
                'total_results' => 1,
                'total_pages' => 1,
                'first' => {
                  'href' => "#{link_prefix}/v3/stacks?default=true&page=1&per_page=50"
                },
                'last' => {
                  'href' => "#{link_prefix}/v3/stacks?default=true&page=1&per_page=50"
                },
                'next' => nil,
                'previous' => nil
              },
              'resources' => [
                {
                  'name' => stack2.name,
                  'description' => stack2.description,
                  'run_rootfs_image' => stack2.run_rootfs_image,
                  'build_rootfs_image' => stack2.build_rootfs_image,
                  'guid' => stack2.guid,
                  'default' => true,
                  'deprecated_at' => nil,
                  'locked_at' => nil,
                  'disabled_at' => nil,
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

        context 'when there are labels' do
          let!(:stack1_label) do
            VCAP::CloudController::StackLabelModel.make(
              key_name: 'release',
              value: 'stable',
              resource_guid: stack1.guid
            )
          end
          let!(:stack2_label) do
            VCAP::CloudController::StackLabelModel.make(
              key_name: 'release',
              value: 'unstable',
              resource_guid: stack2.guid
            )
          end

          it 'returns a list of label filtered stacks' do
            get '/v3/stacks?label_selector=release=stable', nil, user_header

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
                    'run_rootfs_image' => stack1.run_rootfs_image,
                    'build_rootfs_image' => stack1.build_rootfs_image,
                    'guid' => stack1.guid,
                    'default' => false,
                    'deprecated_at' => nil,
                    'locked_at' => nil,
                    'disabled_at' => nil,
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
                    }
                  }
                ]
              }
            )
          end
        end

        context 'when stacks have lifecycle timestamps' do
          let(:deprecated_time) { Time.now.utc + 1.day }
          let(:locked_time) { Time.now.utc + 2.days }
          let(:disabled_time) { Time.now.utc + 3.days }
          let!(:stack_with_timestamps) do
            VCAP::CloudController::Stack.make(
              deprecated_at: deprecated_time,
              locked_at: locked_time,
              disabled_at: disabled_time
            )
          end

          it 'returns stacks with lifecycle timestamps in the list' do
            get '/v3/stacks', nil, user_header

            stack_response = parsed_response['resources'].find { |s| s['guid'] == stack_with_timestamps.guid }
            expect(stack_response['deprecated_at']).to eq(deprecated_time.iso8601)
            expect(stack_response['locked_at']).to eq(locked_time.iso8601)
            expect(stack_response['disabled_at']).to eq(disabled_time.iso8601)
          end
        end
      end
    end
  end

  describe 'GET /v3/stacks/:guid' do
    let(:user) { make_user }
    let(:user_header) { headers_for(user) }
    let(:api_call) { ->(user_header) { get "/v3/stacks/#{stack.guid}", nil, user_header } }
    let!(:stack) { VCAP::CloudController::Stack.make }
    let(:stacks_response_object) do
      {
        'name' => stack.name,
        'description' => stack.description,
        'run_rootfs_image' => stack.run_rootfs_image,
        'build_rootfs_image' => stack.build_rootfs_image,
        'guid' => stack.guid,
        'default' => false,
        'deprecated_at' => nil,
        'locked_at' => nil,
        'disabled_at' => nil,
        'metadata' => { 'labels' => {}, 'annotations' => {} },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/stacks/#{stack.guid}"
          }
        }
      }
    end
    let(:expected_codes_and_responses) do
      Hash.new({ code: 200, response_object: stacks_response_object }.freeze)
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when stack has lifecycle timestamps' do
      let(:deprecated_time) { Time.now.utc + 1.day }
      let(:locked_time) { Time.now.utc + 2.days }
      let(:disabled_time) { Time.now.utc + 3.days }
      let!(:stack_with_timestamps) do
        VCAP::CloudController::Stack.make(
          deprecated_at: deprecated_time,
          locked_at: locked_time,
          disabled_at: disabled_time
        )
      end

      it 'returns the stack with lifecycle timestamps' do
        get "/v3/stacks/#{stack_with_timestamps.guid}", nil, user_header

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => stack_with_timestamps.name,
            'description' => stack_with_timestamps.description,
            'run_rootfs_image' => stack_with_timestamps.run_rootfs_image,
            'build_rootfs_image' => stack_with_timestamps.build_rootfs_image,
            'guid' => stack_with_timestamps.guid,
            'default' => false,
            'deprecated_at' => deprecated_time.iso8601,
            'locked_at' => locked_time.iso8601,
            'disabled_at' => disabled_time.iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/stacks/#{stack_with_timestamps.guid}"
              }
            }
          }
        )
      end
    end

    context 'when stack has partial lifecycle timestamps' do
      let(:deprecated_time) { Time.now.utc + 1.day }
      let!(:stack_deprecated_only) do
        VCAP::CloudController::Stack.make(deprecated_at: deprecated_time)
      end

      it 'returns the stack with only deprecated_at set' do
        get "/v3/stacks/#{stack_deprecated_only.guid}", nil, user_header

        expect(last_response.status).to eq(200)
        expect(parsed_response['deprecated_at']).to eq(deprecated_time.iso8601)
        expect(parsed_response['locked_at']).to be_nil
        expect(parsed_response['disabled_at']).to be_nil
      end
    end
  end

  describe 'GET /v3/stacks/:guid/apps' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }
    let!(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let!(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'bp-name') }
    let!(:space2) { VCAP::CloudController::Space.make }
    let!(:app_model1) { VCAP::CloudController::AppModel.make(name: 'name1', space: space) }
    let!(:app_model2) { VCAP::CloudController::AppModel.make(name: 'name2', space: space2) }
    let!(:app_model3) do
      VCAP::CloudController::AppModel.make(
        :docker,
        name: 'name2'
      )
    end

    before do
      app_model1.buildpack_lifecycle_data.update(stack: stack.name, buildpacks: [buildpack.name])
      app_model2.buildpack_lifecycle_data.update(stack: stack.name, buildpacks: [buildpack.name])
    end

    context 'as a permitted user' do
      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'returns the list of space-visible apps using the given stack' do
        get "/v3/stacks/#{stack.guid}/apps", { per_page: 2 }, headers

        expect(last_response.status).to eq(200), last_response.body
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'last' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'previous' => nil,
              'next' => nil
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
                      'guid' => nil
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
                  'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/features" }
                }
              }
            ]
          }
        )
      end
    end

    context 'as an admin user' do
      let!(:user) { make_user(admin: true) }
      let!(:headers) { admin_headers_for(user) }

      it 'return the list of all apps using the given stack' do
        get "/v3/stacks/#{stack.guid}/apps", { per_page: 2 }, headers

        expect(last_response.status).to eq(200), last_response.body
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'last' => { 'href' => "#{link_prefix}/v3/stacks/#{stack.guid}/apps?page=1&per_page=2" },
              'previous' => nil,
              'next' => nil
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
                      'guid' => nil
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
                  'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/features" }
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
                    'stack' => 'stack-name'
                  }
                },
                'relationships' => {
                  'space' => {
                    'data' => {
                      'guid' => space2.guid
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
                  'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/features" }
                }
              }
            ]
          }
        )
      end
    end

    context 'permissions' do
      let(:api_call) { ->(user_headers) { get "/v3/stacks/#{stack.guid}/apps", nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_guids: [app_model1.guid, app_model2.guid] }.freeze)

        h['org_auditor'] = {
          code: 200,
          response_guids: []
        }

        h['org_billing_manager'] = {
          code: 200,
          response_guids: []
        }

        h['org_manager'] = {
          code: 200,
          response_guids: [
            app_model1.guid
          ]
        }

        h['space_manager'] = {
          code: 200,
          response_guids: [
            app_model1.guid
          ]
        }

        h['space_auditor'] = {
          code: 200,
          response_guids: [
            app_model1.guid
          ]
        }

        h['space_developer'] = {
          code: 200,
          response_guids: [
            app_model1.guid
          ]
        }

        h['space_supporter'] = {
          code: 200,
          response_guids: [
            app_model1.guid
          ]
        }

        h['no_role'] = { code: 200, response_guids: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
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
            potato: 'yam'
          },
          annotations: {
            potato: 'idaho'
          }
        }
      }.to_json
    end
    let(:headers) { admin_headers_for(user) }

    it 'creates a new stack' do
      expect do
        post '/v3/stacks', request_body, headers
      end.to change(VCAP::CloudController::Stack, :count).by 1

      created_stack = VCAP::CloudController::Stack.last

      expect(last_response.status).to eq(201)

      expect(parsed_response).to be_a_response_like(
        {
          'name' => 'the-name',
          'description' => 'the-description',
          'run_rootfs_image' => created_stack.run_rootfs_image,
          'build_rootfs_image' => created_stack.build_rootfs_image,
          'default' => false,
          'deprecated_at' => nil,
          'locked_at' => nil,
          'disabled_at' => nil,
          'metadata' => {
            'labels' => {
              'potato' => 'yam'
            },
            'annotations' => {
              'potato' => 'idaho'
            }
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

    context 'when creating a stack with lifecycle timestamps' do
      let(:deprecated_time) { Time.now.utc + 1.day }
      let(:locked_time) { Time.now.utc + 2.days }
      let(:disabled_time) { Time.now.utc + 3.days }
      let(:request_body_with_timestamps) do
        {
          name: 'lifecycle-stack',
          description: 'stack with lifecycle timestamps',
          deprecated_at: deprecated_time.iso8601,
          locked_at: locked_time.iso8601,
          disabled_at: disabled_time.iso8601
        }.to_json
      end

      it 'creates a stack with the specified lifecycle timestamps' do
        expect do
          post '/v3/stacks', request_body_with_timestamps, headers
        end.to change(VCAP::CloudController::Stack, :count).by 1

        created_stack = VCAP::CloudController::Stack.last

        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => 'lifecycle-stack',
            'description' => 'stack with lifecycle timestamps',
            'run_rootfs_image' => created_stack.run_rootfs_image,
            'build_rootfs_image' => created_stack.build_rootfs_image,
            'default' => false,
            'deprecated_at' => deprecated_time.iso8601,
            'locked_at' => locked_time.iso8601,
            'disabled_at' => disabled_time.iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
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
    end

    context 'when creating a stack with invalid timestamp ordering' do
      let(:request_body_invalid_order) do
        {
          name: 'invalid-stack',
          deprecated_at: (Time.now.utc + 3.days).iso8601,
          locked_at: (Time.now.utc + 1.day).iso8601,
          disabled_at: (Time.now.utc + 2.days).iso8601
        }.to_json
      end

      it 'responds with 422 for invalid timestamp ordering' do
        post '/v3/stacks', request_body_invalid_order, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('deprecated_at must be before locked_at')
      end
    end

    context 'when creating a stack with invalid timestamp format' do
      let(:request_body_invalid_timestamp) do
        {
          name: 'invalid-timestamp-stack',
          deprecated_at: 'not-a-timestamp'
        }.to_json
      end

      it 'responds with 422 for invalid timestamp format' do
        post '/v3/stacks', request_body_invalid_timestamp, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Deprecated at has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
      end
    end

    context 'when there is a model validation failure' do
      let(:name) { 'the-name' }

      before do
        VCAP::CloudController::Stack.make name:
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
          'run_rootfs_image' => stack.run_rootfs_image,
          'build_rootfs_image' => stack.build_rootfs_image,
          'default' => false,
          'deprecated_at' => nil,
          'locked_at' => nil,
          'disabled_at' => nil,
          'metadata' => {
            'labels' => {
              'potato' => 'yam'
            },
            'annotations' => {
              'potato' => 'idaho'
            }
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

    context 'when updating stack lifecycle timestamps' do
      let(:deprecated_time) { Time.now.utc + 1.day }
      let(:locked_time) { Time.now.utc + 2.days }
      let(:disabled_time) { Time.now.utc + 3.days }
      let(:request_body_with_timestamps) do
        {
          deprecated_at: deprecated_time.iso8601,
          locked_at: locked_time.iso8601,
          disabled_at: disabled_time.iso8601
        }.to_json
      end

      it 'updates the stack with the specified lifecycle timestamps' do
        patch "/v3/stacks/#{stack.guid}", request_body_with_timestamps, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(
          {
            'name' => stack.name,
            'description' => stack.description,
            'run_rootfs_image' => stack.run_rootfs_image,
            'build_rootfs_image' => stack.build_rootfs_image,
            'default' => false,
            'deprecated_at' => deprecated_time.iso8601,
            'locked_at' => locked_time.iso8601,
            'disabled_at' => disabled_time.iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
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

    context 'when updating individual lifecycle timestamps' do
      it 'updates only the deprecated_at timestamp' do
        deprecated_time = Time.now.utc + 1.day
        request_body = { deprecated_at: deprecated_time.iso8601 }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['deprecated_at']).to eq(deprecated_time.iso8601)
        expect(parsed_response['locked_at']).to be_nil
        expect(parsed_response['disabled_at']).to be_nil
      end

      it 'updates only the locked_at timestamp' do
        locked_time = Time.now.utc + 2.days
        request_body = { locked_at: locked_time.iso8601 }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['deprecated_at']).to be_nil
        expect(parsed_response['locked_at']).to eq(locked_time.iso8601)
        expect(parsed_response['disabled_at']).to be_nil
      end

      it 'updates only the disabled_at timestamp' do
        disabled_time = Time.now.utc + 3.days
        request_body = { disabled_at: disabled_time.iso8601 }.to_json

        patch "/v3/stacks/#{stack.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['deprecated_at']).to be_nil
        expect(parsed_response['locked_at']).to be_nil
        expect(parsed_response['disabled_at']).to eq(disabled_time.iso8601)
      end
    end

    context 'when updating with invalid timestamp ordering' do
      let(:request_body_invalid_order) do
        {
          deprecated_at: (Time.now.utc + 3.days).iso8601,
          locked_at: (Time.now.utc + 1.day).iso8601,
          disabled_at: (Time.now.utc + 2.days).iso8601
        }.to_json
      end

      it 'responds with 422 for invalid timestamp ordering' do
        patch "/v3/stacks/#{stack.guid}", request_body_invalid_order, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('deprecated_at must be before locked_at')
      end
    end

    context 'when updating with invalid timestamp format' do
      let(:request_body_invalid_timestamp) do
        {
          deprecated_at: 'not-a-timestamp'
        }.to_json
      end

      it 'responds with 422 for invalid timestamp format' do
        patch "/v3/stacks/#{stack.guid}", request_body_invalid_timestamp, headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("Deprecated at has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
      end
    end

    context 'when clearing lifecycle timestamps' do
      let!(:stack_with_timestamps) do
        VCAP::CloudController::Stack.make(
          deprecated_at: Time.now.utc + 1.day,
          locked_at: Time.now.utc + 2.days,
          disabled_at: Time.now.utc + 3.days
        )
      end

      it 'clears timestamps when set to null' do
        request_body = {
          deprecated_at: nil,
          locked_at: nil,
          disabled_at: nil
        }.to_json

        patch "/v3/stacks/#{stack_with_timestamps.guid}", request_body, headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['deprecated_at']).to be_nil
        expect(parsed_response['locked_at']).to be_nil
        expect(parsed_response['disabled_at']).to be_nil
      end
    end
  end

  describe 'DELETE /v3/stacks/:guid' do
    let(:user) { make_user(admin: true) }
    let(:headers) { admin_headers_for(user) }
    let(:stack) { VCAP::CloudController::Stack.make }

    it 'destroys the stack' do
      delete "/v3/stacks/#{stack.guid}", {}, headers

      expect(last_response.status).to eq(204)
      expect(stack).not_to exist
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
