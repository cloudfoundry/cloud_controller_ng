require 'spec_helper'
require 'messages/buildpack_upload_message'
require 'request_spec_shared_examples'

RSpec.describe 'buildpacks' do
  describe 'GET /v3/buildpacks' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    before do
      TestConfig.override(kubernetes: {})
    end

    it 'returns 200 OK' do
      get '/v3/buildpacks', nil, headers
      expect(last_response.status).to eq(200)
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/buildpacks' }

      let(:message) { VCAP::CloudController::BuildpacksListMessage }
      let(:user_header) { headers }
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          names: 'foo',
          stacks: 'cf',
          lifecycle: 'buildpack',
          label_selector: 'foo,bar',
          guids: 'foo,bar',
          created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 }
        }
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Buildpack }
      let(:api_call) do
        ->(headers, filters) { get "/v3/buildpacks?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    context 'when filtered by label_selector' do
      let!(:buildpackA) { VCAP::CloudController::Buildpack.make(name: 'A') }
      let!(:buildpackAFruit) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'fruit', value: 'strawberry', buildpack: buildpackA) }
      let!(:buildpackAAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'horse', buildpack: buildpackA) }

      let!(:buildpackB) { VCAP::CloudController::Buildpack.make(name: 'B') }
      let!(:buildpackBEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackB) }
      let!(:buildpackBAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'dog', buildpack: buildpackB) }

      let!(:buildpackC) { VCAP::CloudController::Buildpack.make(name: 'C') }
      let!(:buildpackCEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackC) }
      let!(:buildpackCAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'horse', buildpack: buildpackC) }

      let!(:buildpackD) { VCAP::CloudController::Buildpack.make(name: 'D') }
      let!(:buildpackDEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackD) }

      let!(:buildpackE) { VCAP::CloudController::Buildpack.make(name: 'E') }
      let!(:buildpackEEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'staging', buildpack: buildpackE) }
      let!(:buildpackEAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'dog', buildpack: buildpackE) }

      it 'returns the matching buildpacks' do
        get '/v3/buildpacks?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_headers
        expect(last_response.status).to eq(200), last_response.body

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(buildpackB.guid, buildpackC.guid)
      end
    end

    context 'when filtered by null stack' do
      let!(:stack) { VCAP::CloudController::Stack.make }
      let!(:buildpack_without_stack) { VCAP::CloudController::Buildpack.make(stack: nil) }
      let!(:buildpack_with_stack) { VCAP::CloudController::Buildpack.make(stack: stack.name) }

      it 'returns the matching buildpacks' do
        get '/v3/buildpacks?stacks=', nil, admin_headers
        expect(last_response.status).to eq(200), last_response.body

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(buildpack_without_stack.guid)
      end
    end

    context 'When buildpacks exist' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }
      let!(:stack3) { VCAP::CloudController::Stack.make }

      let!(:buildpack4) { VCAP::CloudController::Buildpack.make(stack: stack1.name, position: 2, lifecycle: 'cnb') }
      let!(:buildpack5) { VCAP::CloudController::Buildpack.make(stack: stack1.name, position: 1, lifecycle: 'cnb') }

      let!(:buildpack1) { VCAP::CloudController::Buildpack.make(stack: stack1.name, position: 1) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.make(stack: stack2.name, position: 3) }
      let!(:buildpack3) { VCAP::CloudController::Buildpack.make(stack: stack3.name, position: 2) }

      it 'returns a paginated list of buildpacks, sorted by lifecycle and position' do
        get '/v3/buildpacks?page=1&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 5,
              'total_pages' => 3,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=3&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack3.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack3.name,
                'state' => buildpack3.state,
                'filename' => buildpack3.filename,
                'stack' => buildpack3.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'with no filters, returns a list of buildpacks, sorted by lifecycle and position' do
        get '/v3/buildpacks', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 5,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=1&per_page=50"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack3.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack3.name,
                'state' => buildpack3.state,
                'filename' => buildpack3.filename,
                'stack' => buildpack3.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack2.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack2.name,
                'state' => buildpack2.state,
                'filename' => buildpack2.filename,
                'stack' => buildpack2.stack,
                'position' => 3,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack5.guid,
                'lifecycle' => 'cnb',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack5.name,
                'state' => buildpack5.state,
                'filename' => buildpack5.filename,
                'stack' => buildpack5.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack4.guid,
                'lifecycle' => 'cnb',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack4.name,
                'state' => buildpack4.state,
                'filename' => buildpack4.filename,
                'stack' => buildpack4.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'returns a list of filtered buildpacks' do
        get "/v3/buildpacks?names=#{buildpack1.name},#{buildpack3.name}&stacks=#{stack1.name}", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&page=1&per_page=50&stacks=#{stack1.name}"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&page=1&per_page=50&stacks=#{stack1.name}"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => stack1.name,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'returns a paginated list of buildpacks filtered by lifecycle' do
        get '/v3/buildpacks?lifecycle=buildpack&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?lifecycle=buildpack&page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?lifecycle=buildpack&page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/buildpacks?lifecycle=buildpack&page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack3.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack3.name,
                'state' => buildpack3.state,
                'filename' => buildpack3.filename,
                'stack' => buildpack3.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'returns a list of buildpacks filtered by lifecycle' do
        get '/v3/buildpacks?lifecycle=cnb', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?lifecycle=cnb&page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?lifecycle=cnb&page=1&per_page=50"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack5.guid,
                'lifecycle' => 'cnb',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack5.name,
                'state' => buildpack5.state,
                'filename' => buildpack5.filename,
                'stack' => buildpack5.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack4.guid,
                'lifecycle' => 'cnb',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack4.name,
                'state' => buildpack4.state,
                'filename' => buildpack4.filename,
                'stack' => buildpack4.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'orders by position' do
        get "/v3/buildpacks?names=#{buildpack1.name},#{buildpack3.name}&order_by=-position", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&order_by=-position&page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&order_by=-position&page=1&per_page=50"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack3.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack3.name,
                'state' => buildpack3.state,
                'filename' => buildpack3.filename,
                'stack' => buildpack3.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack1.guid,
                'lifecycle' => 'buildpack',
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'reverse orders by lifecycle (with position as secondary)' do
        get '/v3/buildpacks?order_by=-lifecycle', nil, headers

        expect(parsed_response).to(be_a_response_like(
                                     {
                                       'pagination' => {
                                         'total_results' => 5,
                                         'total_pages' => 1,
                                         'first' => {
                                           'href' => "#{link_prefix}/v3/buildpacks?order_by=-lifecycle&page=1&per_page=50"
                                         },
                                         'last' => {
                                           'href' => "#{link_prefix}/v3/buildpacks?order_by=-lifecycle&page=1&per_page=50"
                                         },
                                         'next' => nil,
                                         'previous' => nil
                                       },
                                       'resources' => [
                                         {
                                           'guid' => buildpack4.guid,
                                           'lifecycle' => 'cnb',
                                           'created_at' => iso8601,
                                           'updated_at' => iso8601,
                                           'name' => buildpack4.name,
                                           'state' => buildpack4.state,
                                           'filename' => buildpack4.filename,
                                           'stack' => buildpack4.stack,
                                           'position' => 2,
                                           'enabled' => true,
                                           'locked' => false,
                                           'metadata' => { 'labels' => {}, 'annotations' => {} },
                                           'links' => {
                                             'self' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}"
                                             },
                                             'upload' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack4.guid}/upload",
                                               'method' => 'POST'
                                             }
                                           }
                                         },
                                         {
                                           'guid' => buildpack5.guid,
                                           'lifecycle' => 'cnb',
                                           'created_at' => iso8601,
                                           'updated_at' => iso8601,
                                           'name' => buildpack5.name,
                                           'state' => buildpack5.state,
                                           'filename' => buildpack5.filename,
                                           'stack' => buildpack5.stack,
                                           'position' => 1,
                                           'enabled' => true,
                                           'locked' => false,
                                           'metadata' => { 'labels' => {}, 'annotations' => {} },
                                           'links' => {
                                             'self' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}"
                                             },
                                             'upload' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack5.guid}/upload",
                                               'method' => 'POST'
                                             }
                                           }
                                         },
                                         {
                                           'guid' => buildpack2.guid,
                                           'lifecycle' => 'buildpack',
                                           'created_at' => iso8601,
                                           'updated_at' => iso8601,
                                           'name' => buildpack2.name,
                                           'state' => buildpack2.state,
                                           'filename' => buildpack2.filename,
                                           'stack' => buildpack2.stack,
                                           'position' => 3,
                                           'enabled' => true,
                                           'locked' => false,
                                           'metadata' => { 'labels' => {}, 'annotations' => {} },
                                           'links' => {
                                             'self' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}"
                                             },
                                             'upload' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}/upload",
                                               'method' => 'POST'
                                             }
                                           }
                                         },
                                         {
                                           'guid' => buildpack3.guid,
                                           'lifecycle' => 'buildpack',
                                           'created_at' => iso8601,
                                           'updated_at' => iso8601,
                                           'name' => buildpack3.name,
                                           'state' => buildpack3.state,
                                           'filename' => buildpack3.filename,
                                           'stack' => buildpack3.stack,
                                           'position' => 2,
                                           'enabled' => true,
                                           'locked' => false,
                                           'metadata' => { 'labels' => {}, 'annotations' => {} },
                                           'links' => {
                                             'self' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                                             },
                                             'upload' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                                               'method' => 'POST'
                                             }
                                           }
                                         },
                                         {
                                           'guid' => buildpack1.guid,
                                           'lifecycle' => 'buildpack',
                                           'created_at' => iso8601,
                                           'updated_at' => iso8601,
                                           'name' => buildpack1.name,
                                           'state' => buildpack1.state,
                                           'filename' => buildpack1.filename,
                                           'stack' => buildpack1.stack,
                                           'position' => 1,
                                           'enabled' => true,
                                           'locked' => false,
                                           'metadata' => { 'labels' => {}, 'annotations' => {} },
                                           'links' => {
                                             'self' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                                             },
                                             'upload' => {
                                               'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                                               'method' => 'POST'
                                             }
                                           }
                                         }

                                       ]
                                     }
                                   ))
      end
    end

    context 'permissions' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:api_call) { ->(user_headers) { get '/v3/buildpacks', nil, user_headers } }
      let(:expected_codes_and_responses) { Hash.new({ code: 200 }.freeze) }

      before do
        space.organization.add_user(user)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end

  describe 'POST /v3/buildpacks' do
    context 'when not authenticated' do
      let(:headers) { {} }

      it 'returns 401' do
        post '/v3/buildpacks', nil, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when successful' do
        let(:stack) { VCAP::CloudController::Stack.make }
        let(:params) do
          {
            name: 'the-r3al_Name',
            stack: stack.name,
            enabled: false,
            locked: true,
            metadata: {
              labels: {
                potato: 'yam'
              },
              annotations: {
                potato: 'idaho'
              }
            }
          }
        end

        it 'returns 201' do
          post '/v3/buildpacks', params.to_json, headers

          expect(last_response.status).to eq(201)
        end

        describe 'non-position values' do
          it 'returns the newly-created buildpack resource' do
            post '/v3/buildpacks', params.to_json, headers

            buildpack = VCAP::CloudController::Buildpack.last

            expected_response = {
              'name' => params[:name],
              'state' => 'AWAITING_UPLOAD',
              'filename' => nil,
              'stack' => params[:stack],
              'position' => 1,
              'enabled' => params[:enabled],
              'locked' => params[:locked],
              'guid' => buildpack.guid,
              'lifecycle' => 'buildpack',
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'metadata' => {
                'labels' => {
                  'potato' => 'yam'
                },
                'annotations' => {
                  'potato' => 'idaho'
                }
              },
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
                },
                'upload' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload",
                  'method' => 'POST'
                }
              }
            }
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end

        describe 'position' do
          let!(:buildpack1) { VCAP::CloudController::Buildpack.make(position: 1) }
          let!(:buildpack2) { VCAP::CloudController::Buildpack.make(position: 2) }
          let!(:buildpack3) { VCAP::CloudController::Buildpack.make(position: 3) }

          context 'the position is not provided' do
            it 'defaults the position value to 1' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(1)
              expect(buildpack1.reload.position).to eq(2)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is less than or equal to the total number of buildpacks' do
            before do
              params[:position] = 2
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(2)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is greater than the total number of buildpacks' do
            before do
              params[:position] = 42
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(4)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(2)
              expect(buildpack3.reload.position).to eq(3)
            end
          end
        end
      end
    end
  end

  describe 'GET /v3/buildpacks/:guid' do
    let(:params) { {} }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    context 'when not authenticated' do
      it 'returns 401' do
        headers = {}

        get "/v3/buildpacks/#{buildpack.guid}", params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      let(:user) { VCAP::CloudController::User.make }

      before do
        space.organization.add_user(user)
      end

      context 'the buildpack does not exist' do
        let(:api_call) { ->(user_headers) { get '/v3/buildpacks/does-not-exist', nil, user_headers } }

        let(:expected_codes_and_responses) { Hash.new({ code: 404 }.freeze) }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'the buildpack exists' do
        let(:api_call) { ->(user_headers) { get "/v3/buildpacks/#{buildpack.guid}", nil, user_headers } }
        let(:buildpack_response) do
          {
            'name' => buildpack.name,
            'state' => buildpack.state,
            'stack' => buildpack.stack,
            'filename' => buildpack.filename,
            'position' => buildpack.position,
            'enabled' => buildpack.enabled,
            'locked' => buildpack.locked,
            'guid' => buildpack.guid,
            'lifecycle' => 'buildpack',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
              },
              'upload' => {
                'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload",
                'method' => 'POST'
              }
            }
          }
        end

        let(:expected_codes_and_responses) { Hash.new({ code: 200, response_object: buildpack_response }.freeze) }

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
  end

  describe 'DELETE /v3/buildpacks/:guid' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    it 'deletes a buildpack asynchronously' do
      delete "/v3/buildpacks/#{buildpack.guid}", nil, admin_headers

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r{http.+/v3/jobs/[a-fA-F0-9-]+})

      execute_all_jobs(expected_successes: 2, expected_failures: 0)
      get "/v3/buildpacks/#{buildpack.guid}", {}, admin_headers
      expect(last_response.status).to eq(404)
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { buildpack }
        let(:api_call) do
          -> { delete "/v3/buildpacks/#{resource.guid}", nil, admin_headers }
        end
      end
    end
  end

  describe 'POST /v3/buildpacks/:guid/upload' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    before do
      allow_any_instance_of(VCAP::CloudController::BuildpackUploadMessage).to receive(:valid?).and_return(true)
    end

    it 'enqueues a job to process the uploaded bits' do
      file_upload_params = {
        bits_name: 'buildpack.zip',
        bits_path: 'tmpdir/buildpack.zip'
      }

      expect(Delayed::Job.count).to eq 0

      post "/v3/buildpacks/#{buildpack.guid}/upload", file_upload_params.to_json, admin_headers

      expect(Delayed::Job.count).to eq 1

      expect(last_response.status).to eq(202)

      get last_response.headers['Location'], nil, admin_headers

      expect(last_response.status).to eq(200)
    end
  end

  describe 'PATCH /v3/buildpacks/:guid' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    it 'updates a buildpack' do
      params = { enabled: false }

      patch "/v3/buildpacks/#{buildpack.guid}", params.to_json, admin_headers

      expect(parsed_response['enabled']).to be(false)
      expect(last_response.status).to eq(200)
      expect(buildpack.reload).not_to be_enabled
    end
  end
end
