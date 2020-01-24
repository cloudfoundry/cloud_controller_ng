require 'spec_helper'
require 'presenters/v3/service_plan_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServicePlanPresenter do
  let(:guid) { 'some-plan-guid' }

  let(:service_plan) do
    VCAP::CloudController::ServicePlan.make(guid: guid)
  end

  describe '#to_hash' do
    let(:result) { described_class.new(service_plan).to_hash }

    it 'presents the service plan' do
      expect(result).to eq({
        guid: guid,
        created_at: service_plan.created_at,
        updated_at: service_plan.updated_at,
        public: true,
        available: true,
        name: service_plan.name,
        free: false,
        description: service_plan.description,
        broker_catalog: {
          metadata: {},
          id: service_plan.unique_id,
          features: {
            bindable: true,
            plan_updateable: false
          }
        },
        schemas: {
          service_instance: {
            create: {},
            update: {}
          },
          service_binding: {
            create: {}
          }
        }
      })
    end

    context 'when `public` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, public: false)
      end

      it 'presents the service plan with public false' do
        expect(result[:public]).to eq(false)
      end
    end

    context 'when `active` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, active: false)
      end

      it 'presents the service plan with available false' do
        expect(result[:available]).to eq(false)
      end
    end

    context 'when `free` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, free: false)
      end

      it 'presents the service plan with free false' do
        expect(result[:free]).to eq(false)
      end
    end

    context 'when `bindable` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, bindable: false)
      end

      it 'presents the service plan with bindable false' do
        expect(result[:broker_catalog][:features][:bindable]).to eq(false)
      end
    end

    context 'when `plan_updateable` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, plan_updateable: false)
      end

      it 'presents the service plan with plan_updateable false' do
        expect(result[:broker_catalog][:features][:plan_updateable]).to eq(false)
      end
    end

    context 'when plan has `extra`' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(guid: guid, extra: '{"some_key": "some-value"}')
      end

      it 'presents the service plan with metadata' do
        expect(result[:broker_catalog][:metadata]['some_key']).to eq('some-value')
      end
    end

    context 'schemas' do
      let(:schema) {
        '{
            "$schema": "http://json-schema.org/draft-04/schema#",
            "type": "object",
            "properties": {
              "billing-account": {
                "description": "Billing account number used to charge use of shared fake server.",
                "type": "string"
              }
            }
          }'
      }

      context 'when plan has create service_instance schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(guid: guid, create_instance_schema: schema)
        end

        it 'presents the service plan create service_instance with the schema' do
          expect(result[:schemas][:service_instance][:create][:parameters]).to eq(JSON.parse(schema))
          expect(result[:schemas][:service_instance][:update]).to be_empty
          expect(result[:schemas][:service_binding][:create]).to be_empty
        end
      end

      context 'when plan has update service_instance schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(guid: guid, update_instance_schema: schema)
        end

        it 'presents the service plan update service_instance with the schema' do
          expect(result[:schemas][:service_instance][:update][:parameters]).to eq(JSON.parse(schema))
          expect(result[:schemas][:service_instance][:create]).to be_empty
          expect(result[:schemas][:service_binding][:create]).to be_empty
        end
      end

      context 'when plan has create service_binding schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(guid: guid, create_binding_schema: schema)
        end

        it 'presents the service plan update service_instance with the schema' do
          expect(result[:schemas][:service_instance][:update]).to be_empty
          expect(result[:schemas][:service_instance][:create]).to be_empty
          expect(result[:schemas][:service_binding][:create][:parameters]).to eq(JSON.parse(schema))
        end
      end
    end
  end
end
