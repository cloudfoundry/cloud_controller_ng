require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::QuotaDefinitionsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          non_basic_services_allowed: { type: 'bool', required: true },
          total_services: { type: 'integer', required: true },
          total_service_keys: { type: 'integer', required: false, default: -1 },
          total_routes: { type: 'integer', required: true },
          total_private_domains: { type: 'integer', required: false, default: -1 },
          memory_limit: { type: 'integer', required: true },
          instance_memory_limit: { type: 'integer', required: false, default: -1 },
          app_instance_limit: { type: 'integer', required: false, default: -1 },
          total_reserved_route_ports: { type: 'integer', required: false, default: 0 },
          app_task_limit: { type: 'integer', required: false, default: -1 }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          non_basic_services_allowed: { type: 'bool' },
          total_services: { type: 'integer' },
          total_service_keys: { type: 'integer' },
          total_routes: { type: 'integer' },
          total_private_domains: { type: 'integer' },
          memory_limit: { type: 'integer' },
          instance_memory_limit: { type: 'integer' },
          app_instance_limit: { type: 'integer' },
          total_reserved_route_ports: { type: 'integer' },
          app_task_limit: { type: 'integer' }
        })
      end
    end

    describe 'permissions' do
      let(:quota_attributes) do
        {
          name: quota_name,
          non_basic_services_allowed: false,
          total_services: 1,
          total_routes: 10,
          total_private_domains: 20,
          total_reserved_route_ports: 2,
          memory_limit: 1024,
          instance_memory_limit: 10_240,
          app_task_limit: 10
        }
      end
      let(:existing_quota) { VCAP::CloudController::QuotaDefinition.make }

      context 'when the user is a cf admin' do
        let(:quota_name) { 'quota 1' }

        before { set_current_user_as_admin }

        it 'does allow creation of a quota def' do
          post '/v2/quota_definitions', MultiJson.dump(quota_attributes)
          expect(last_response.status).to eq(201)
        end

        it 'does allow read of a quota def' do
          get "/v2/quota_definitions/#{existing_quota.guid}"
          expect(last_response.status).to eq(200)
        end

        it 'does allow update of a quota def' do
          put "/v2/quota_definitions/#{existing_quota.guid}", MultiJson.dump({ total_services: 2 })
          expect(last_response.status).to eq(201)
        end

        it 'does allow deletion of a quota def' do
          delete "/v2/quota_definitions/#{existing_quota.guid}"
          expect(last_response.status).to eq(204)
        end
      end

      context 'when the user is not a cf admin' do
        let(:quota_name) { 'quota 2' }

        before { set_current_user(User.make) }

        it 'does not allow creation of a quota def' do
          post '/v2/quota_definitions', MultiJson.dump(quota_attributes)
          expect(last_response.status).to eq(403)
        end

        it 'does allow read of a quota def' do
          get "/v2/quota_definitions/#{existing_quota.guid}"
          expect(last_response.status).to eq(200)
        end

        it 'does not allow update of a quota def' do
          put "/v2/quota_definitions/#{existing_quota.guid}", MultiJson.dump(quota_attributes)
          expect(last_response.status).to eq(403)
        end

        it 'does not allow deletion of a quota def' do
          delete "/v2/quota_definitions/#{existing_quota.guid}"
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'Validation messages' do
      let(:quota_definition) { QuotaDefinition.make }

      it 'returns QuotaDefinitionMemoryLimitNegative error correctly' do
        set_current_user_as_admin

        put "/v2/quota_definitions/#{quota_definition.guid}", MultiJson.dump({ memory_limit: -100 })

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(240004)
      end
    end
  end
end
