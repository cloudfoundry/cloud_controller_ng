require 'spec_helper'

RSpec.describe 'ServicePlans' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  let(:service) { VCAP::CloudController::Service.make }
  let!(:service_plan) do
    VCAP::CloudController::ServicePlan.make(
      service: service,
      maintenance_info: { version: '2.0', description: 'Test description' },
    )
  end

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/service_plans' do
    it 'lists service plans' do
      get '/v2/service_plans', nil, headers_for(user)
      expect(last_response).to have_status_code(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages' => 1,
          'prev_url' => nil,
          'next_url' => nil,
          'resources' => [
            {
              'metadata' => {
                'guid' => service_plan.guid,
                'url' => "/v2/service_plans/#{service_plan.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'active' => true,
                'bindable' => true,
                'description' => service_plan.description,
                'extra' => nil,
                'free' => false,
                'maximum_polling_duration' => nil,
                'maintenance_info' => {
                  'version' => '2.0',
                  'description' => 'Test description'
                },
                'name' => service_plan.name,
                'plan_updateable' => nil,
                'public' => true,
                'schemas' => {
                   'service_instance' => {
                      'create' => {
                         'parameters' => {}
                      },
                      'update' => {
                         'parameters' => {}
                      }
                   },
                   'service_binding' => {
                      'create' => {
                         'parameters' => {}
                      }
                   }
                },
                'service_guid' => service.guid,
                'service_instances_url' => "/v2/service_plans/#{service_plan.guid}/service_instances",
                'service_url' => "/v2/services/#{service.guid}",
                'unique_id' => service_plan.unique_id
              }
            }
          ]
        }
      )
    end
  end

  describe 'GET /v2/service_plans/:guid' do
    it 'lists service plans' do
      get "/v2/service_plans/#{service_plan.guid}", nil, headers_for(user)
      expect(last_response).to have_status_code(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid' => service_plan.guid,
            'url' => "/v2/service_plans/#{service_plan.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'active' => true,
            'bindable' => true,
            'description' => service_plan.description,
            'extra' => nil,
            'free' => false,
            'maximum_polling_duration' => nil,
            'maintenance_info' => {
              'version' => '2.0',
              'description' => 'Test description'
            },
            'name' => service_plan.name,
            'plan_updateable' => nil,
            'public' => true,
            'schemas' => {
               'service_instance' => {
                  'create' => {
                     'parameters' => {}
                  },
                  'update' => {
                     'parameters' => {}
                  }
               },
               'service_binding' => {
                  'create' => {
                     'parameters' => {}
                  }
               }
            },
            'service_guid' => service.guid,
            'service_instances_url' => "/v2/service_plans/#{service_plan.guid}/service_instances",
            'service_url' => "/v2/services/#{service.guid}",
            'unique_id' => service_plan.unique_id
          }
        },
      )
    end
  end
end
