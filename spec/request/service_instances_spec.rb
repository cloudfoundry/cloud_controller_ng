require 'spec_helper'

RSpec.describe 'Service Instances' do
  let(:user_email) { 'user@email.example.com' }
  let(:user_name) { 'username' }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:admin_header) { admin_headers_for(user, email: user_email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:another_space) { VCAP::CloudController::Space.make }
  let(:target_space) { VCAP::CloudController::Space.make }
  let(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: false, error_message: nil) }
  let!(:service_instance1) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'rabbitmq') }
  let!(:service_instance2) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'redis') }
  let!(:service_instance3) { VCAP::CloudController::ManagedServiceInstance.make(space: another_space, name: 'mysql') }

  describe 'GET /v3/service_instances' do
    it 'returns a paginated list of service instances the user has access to' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      set_current_user_as_role(role: 'space_developer', org: another_space.organization, space: another_space, user: user)
      get '/v3/service_instances?per_page=2&order_by=name', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 3,
            'total_pages' => 2,
            'first' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=%2Bname&page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=%2Bname&page=2&per_page=2"
            },
            'next' => {
              'href' => "#{link_prefix}/v3/service_instances?order_by=%2Bname&page=2&per_page=2"
            },
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => service_instance3.guid,
              'name' => service_instance3.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'space' => {
                  'data' => {
                    'guid' => service_instance3.space.guid
                  }
                }
              },
              'links' => {
                'space' => {
                  'href' => "#{link_prefix}/v3/spaces/#{service_instance3.space.guid}"
                }
              }
            },
            {
              'guid' => service_instance1.guid,
              'name' => service_instance1.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'space' => {
                  'data' => {
                    'guid' => service_instance1.space.guid
                  }
                }
              },
              'links' => {
                'space' => {
                  'href' => "#{link_prefix}/v3/spaces/#{service_instance1.space.guid}"
                }
              }
            }
          ]
        }
      )
    end

    it 'returns a paginated list of service instances filtered by name' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      get '/v3/service_instances?per_page=2&names=redis', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/service_instances?names=redis&page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/service_instances?names=redis&page=1&per_page=2"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => service_instance2.guid,
              'name' => service_instance2.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'space' => {
                  'data' => {
                    'guid' => service_instance2.space.guid
                  }
                }
              },
              'links' => {
                'space' => {
                  'href' => "#{link_prefix}/v3/spaces/#{service_instance2.space.guid}"
                }
              }
            }
          ]
        }
      )
    end

    it 'returns a paginated list of service instances filtered by space guid' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
      get "/v3/service_instances?per_page=2&space_guids=#{space.guid}", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/service_instances?page=1&per_page=2&space_guids=#{space.guid}"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/service_instances?page=1&per_page=2&space_guids=#{space.guid}"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => service_instance1.guid,
              'name' => service_instance1.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'space' => {
                  'data' => {
                   'guid' => service_instance1.space.guid
                  }
                }
              },
              'links' => {
                'space' => {
                  'href' => "#{link_prefix}/v3/spaces/#{service_instance1.space.guid}"
                }
              }
            },
            {
              'guid' => service_instance2.guid,
              'name' => service_instance2.name,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'relationships' => {
                'space' => {
                  'data' => {
                    'guid' => service_instance2.space.guid
                  }
                }
              },
              'links' => {
                'space' => {
                  'href' => "#{link_prefix}/v3/spaces/#{service_instance2.space.guid}"
                }
              }
            }
          ]
        }
      )
    end

    context 'when a user has access to a shared service instance' do
      before do
        service_instance1.add_shared_space(target_space)
      end

      it 'returns a paginated list of service instances the user has access to' do
        set_current_user_as_role(role: 'space_developer', org: target_space.organization, space: target_space, user: user)
        get '/v3/service_instances?per_page=2&order_by=name', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/service_instances?order_by=%2Bname&page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/service_instances?order_by=%2Bname&page=1&per_page=2"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => service_instance1.guid,
                'name' => service_instance1.name,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => {
                  'space' => {
                    'data' => {
                      'guid' => service_instance1.space.guid
                    }
                  }
                },
                'links' => {
                  'space' => {
                    'href' => "#{link_prefix}/v3/spaces/#{service_instance1.space.guid}"
                  }
                }
              }
            ]
          }
        )
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/relationships/shared_spaces' do
    before do
      share_request = {
        'data' => [
          { 'guid' => target_space.guid }
        ]
      }

      enable_feature_flag!
      post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
      expect(last_response.status).to eq(200)

      disable_feature_flag!
    end

    it 'returns a list of space guids where the service instance is shared to' do
      set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)

      get "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", nil, user_header

      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => target_space.guid }
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
    before do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    it 'shares the service instance with the target space' do
      share_request = {
        'data' => [
          { 'guid' => target_space.guid }
        ]
      }

      post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)

      expected_response = {
        'data' => [
          { 'guid' => target_space.guid }
        ],
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces" },
        }
      }

      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.service_instance.share',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             service_instance1.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance1.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guids']).to eq([target_space.guid])
    end
  end

  describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space-guid' do
    before do
      allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new) do |*args, **kwargs, &block|
        FakeServiceBrokerV2Client.new(*args, **kwargs, &block)
      end

      share_request = {
        'data' => [
          { 'guid' => target_space.guid }
        ]
      }

      enable_feature_flag!
      post "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces", share_request.to_json, admin_header
      expect(last_response.status).to eq(200)

      disable_feature_flag!
    end

    it 'unshares the service instance from the target space' do
      delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.service_instance.unshare',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        user_email,
        actor_username:    user_name,
        actee:             service_instance1.guid,
        actee_type:        'service_instance',
        actee_name:        service_instance1.name,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)
    end

    it 'deletes associated bindings in target space when service instance is unshared' do
      process = VCAP::CloudController::ProcessModelFactory.make(diego: false, space: target_space)

      enable_feature_flag!
      service_binding = VCAP::CloudController::ServiceBinding.make(service_instance: service_instance1, app: process.app, credentials: { secret: 'key' })
      disable_feature_flag!

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(200)

      delete "/v3/service_instances/#{service_instance1.guid}/relationships/shared_spaces/#{target_space.guid}", nil, admin_header
      expect(last_response.status).to eq(204)

      get "/v2/service_bindings/#{service_binding.guid}", nil, admin_header
      expect(last_response.status).to eq(404)
    end
  end

  def enable_feature_flag!
    feature_flag.enabled = true
    feature_flag.save
  end

  def disable_feature_flag!
    feature_flag.enabled = false
    feature_flag.save
  end
end
