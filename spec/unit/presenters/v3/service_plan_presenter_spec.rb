require 'spec_helper'
require 'presenters/v3/service_plan_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServicePlanPresenter do
  let(:guid) { service_plan.guid }
  let(:maintenance_info) do
    {
    version: '1.0.0',
      description: 'best plan ever'
  }
  end
  let(:service_plan) do
    VCAP::CloudController::ServicePlan.make(maintenance_info: maintenance_info)
  end

  let!(:potato_label) do
    VCAP::CloudController::ServicePlanLabelModel.make(
      key_prefix: 'canberra.au',
      key_name: 'potato',
      value: 'mashed',
      resource_guid: service_plan.guid
    )
  end

  let!(:mountain_annotation) do
    VCAP::CloudController::ServicePlanAnnotationModel.make(
      key: 'altitude',
      value: '14,412',
      resource_guid: service_plan.guid,
    )
  end

  describe '#to_hash' do
    let(:result) { described_class.new(service_plan).to_hash.deep_symbolize_keys }

    it 'presents the service plan' do
      expect(result).to eq({
        guid: guid,
        created_at: service_plan.created_at,
        updated_at: service_plan.updated_at,
        visibility_type: 'public',
        available: true,
        name: service_plan.name,
        free: false,
        costs: [],
        description: service_plan.description,
        maintenance_info: {
          version: '1.0.0',
          description: 'best plan ever'
        },
        broker_catalog: {
          metadata: {},
          id: service_plan.unique_id,
          maximum_polling_duration: nil,
          features: {
            bindable: true,
            plan_updateable: false
          }
        },
        schemas: {
          service_instance: {
            create: {
              parameters: {}
            },
            update: {
              parameters: {}
            }
          },
          service_binding: {
            create: {
              parameters: {}
            }
          }
        },
        metadata: {
          labels: {
            'canberra.au/potato': 'mashed'
          },
          annotations: {
            altitude: '14,412'
          }
        },
        relationships: {
          service_offering: {
            data: {
              guid: service_plan.service.guid
            }
          }
        },
        links: {
          self: {
            href: "#{link_prefix}/v3/service_plans/#{guid}"
          },
          service_offering: {
            href: "#{link_prefix}/v3/service_offerings/#{service_plan.service.guid}"
          },
          visibility: {
            href: "#{link_prefix}/v3/service_plans/#{service_plan.guid}/visibility"
          }
        }
      })
    end

    context 'when `active` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(active: false)
      end

      it 'presents the service plan with available false' do
        expect(result[:available]).to eq(false)
      end
    end

    context 'when `free` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(free: false)
      end

      it 'presents the service plan with free false' do
        expect(result[:free]).to eq(false)
      end
    end

    context 'when plan has `maximum_polling_duration`' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(maximum_polling_duration: 60)
      end

      it 'presents the service plan with maximum_polling_duration' do
        expect(result[:broker_catalog][:maximum_polling_duration]).to eq(60)
      end
    end

    context 'when `bindable` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(bindable: false)
      end

      it 'presents the service plan with bindable false' do
        expect(result[:broker_catalog][:features][:bindable]).to eq(false)
      end
    end

    context 'when `plan_updateable` is false' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(plan_updateable: false)
      end

      it 'presents the service plan with plan_updateable false' do
        expect(result[:broker_catalog][:features][:plan_updateable]).to eq(false)
      end
    end

    context 'when plan has `extra`' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(extra: '{"some_key": "some-value"}')
      end

      it 'presents the service plan with metadata' do
        expect(result[:broker_catalog][:metadata][:some_key]).to eq('some-value')
      end
    end

    context 'when plan has costs' do
      it 'flattens different currencies in the same unit' do
        service_plan =
          VCAP::CloudController::ServicePlan.make(extra: '{"costs": [
          {
            "amount": {
              "usd": 649.0,
              "gbp": 500
            },
            "unit": "MONTHLY"
          },
          {
            "amount": {
              "usd": 6.00,
              "gbp": 5.05
            },
            "unit": "daily"
          }
        ]}')

        result = described_class.new(service_plan).to_hash.deep_symbolize_keys

        expect(result[:costs][0][:amount]).to eq(649.0)
        expect(result[:costs][0][:currency]).to eq('USD')
        expect(result[:costs][0][:unit]).to eq('MONTHLY')

        expect(result[:costs][1][:amount]).to eq(500.0)
        expect(result[:costs][1][:currency]).to eq('GBP')
        expect(result[:costs][1][:unit]).to eq('MONTHLY')

        expect(result[:costs][2][:amount]).to eq(6.00)
        expect(result[:costs][2][:currency]).to eq('USD')
        expect(result[:costs][2][:unit]).to eq('daily')

        expect(result[:costs][3][:amount]).to eq(5.05)
        expect(result[:costs][3][:currency]).to eq('GBP')
        expect(result[:costs][3][:unit]).to eq('daily')
      end

      it 'handles currency symbols' do
        service_plan =
          VCAP::CloudController::ServicePlan.make(extra: '{"costs": [
          {
            "amount": {
              "$": 0.06
            },
            "unit": "Daily"
          }
        ]}')

        result = described_class.new(service_plan).to_hash.deep_symbolize_keys

        expect(result[:costs][0][:amount]).to eq(0.06)
        expect(result[:costs][0][:currency]).to eq('$')
        expect(result[:costs][0][:unit]).to eq('Daily')
      end
    end

    context 'when plan has no cost' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make
      end

      it 'presents the service plan with cost' do
        expect(result[:costs]).to eq([])
      end
    end

    context 'when plan cost is not valid array' do
      [
        ['cost is not an array',
         '{
            "costs":
              {
                "amount": {
                  "usd": 649.0,
                  "gbp": 600.015454
                },
                "unit": "MONTHLY"
              }
           }'
        ],
        ['amount missing',
         '{
            "costs": [
              {
                "unit": "Weekly"
              },
              {
                "amount": {
                  "usd": 649.0,
                  "gbp": 600.015454
                },
                "unit": "Weekly"
              }
            ]
           }'
        ],
        ['unit is missing',
         '{
            "costs": [
              {
                "amount": {
                  "usd": 649.0
                },
                "unit": "Daily"
              },
              {
                "amount": {
                  "usd": 649.0,
                  "gbp": 600.015454
                }
              }
            ]
           }'
        ],
        ['amount is empty object',
         '{
            "costs": [
              {
                "amount": {},
                "unit": "Daily"
              },
              {
                "amount": {
                  "usd": 649.0
                },
                "unit": "Daily"
              }
            ]
           }'
        ],
        ['amount is not a valid string:float key value pair',
         '{
            "costs": [
              {
                "amount": {
                  "usd": "649.0"
                },
                "unit": "Weekly"
              }
            ]
           }'
        ],
        ['currency is empty string',
         '{
             "costs": [
                {
                  "amount": {
                    "gpb": 0.06
                  },
                  "unit": "Daily"
                },
                {
                  "amount": {
                    "": 0.06,
                    "usd": 0.10
                  },
                  "unit": "Daily"
                }
            ]
          }'
        ],
        ['unit is empty string',
         '{
             "costs": [
                {
                  "amount": {
                    "gpb": 0.06
                  },
                  "unit": "Daily"
                },
                {
                  "amount": {
                    "usd": 0.10
                  },
                  "unit": ""
                }
            ]
          }'
        ]
      ].each do |scenario, extra|
        it "returns empty cost array when #{scenario}" do
          service_plan = VCAP::CloudController::ServicePlan.make(extra: extra)

          result = described_class.new(service_plan).to_hash.deep_symbolize_keys

          expect(result[:costs]).to eq([])
        end
      end
    end

    context 'when plan has no `maintenance_info`' do
      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make
      end

      it 'presents the service plan with empty maintenance_info' do
        expect(result[:maintenance_info]).to be_empty
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

      let(:parsed_schema) { JSON.parse(schema).deep_symbolize_keys }

      context 'when plan has create service_instance schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(create_instance_schema: schema)
        end

        it 'presents the service plan create service_instance with the schema' do
          expect(result[:schemas][:service_instance][:create][:parameters]).to eq(parsed_schema)
          expect(result[:schemas][:service_instance][:update][:parameters]).to be_empty
          expect(result[:schemas][:service_binding][:create][:parameters]).to be_empty
        end
      end

      context 'when plan has update service_instance schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(update_instance_schema: schema)
        end

        it 'presents the service plan update service_instance with the schema' do
          expect(result[:schemas][:service_instance][:update][:parameters]).to eq(parsed_schema)
          expect(result[:schemas][:service_instance][:create][:parameters]).to be_empty
          expect(result[:schemas][:service_binding][:create][:parameters]).to be_empty
        end
      end

      context 'when plan has create service_binding schema' do
        let(:service_plan) do
          VCAP::CloudController::ServicePlan.make(create_binding_schema: schema)
        end

        it 'presents the service plan update service_instance with the schema' do
          expect(result[:schemas][:service_instance][:update][:parameters]).to be_empty
          expect(result[:schemas][:service_instance][:create][:parameters]).to be_empty
          expect(result[:schemas][:service_binding][:create][:parameters]).to eq(parsed_schema)
        end
      end
    end

    context 'when service plan is from a space-scoped broker' do
      let(:space) { VCAP::CloudController::Space.make }
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make(space: space) }
      let(:service_offering) { VCAP::CloudController::Service.make(service_broker: service_broker) }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service_offering) }

      it 'includes a space relationship and link' do
        expect(result).to include({
          relationships: include({
            space: { data: { guid: space.guid } }
          }),
          links: include({
            space: { href: "#{link_prefix}/v3/spaces/#{space.guid}" }
          })
        })
      end
    end

    context 'when a decorator is provided' do
      class FakeDecorator
        def self.decorate(hash, resources)
          hash[:included] = { resource: { guid: resources[0].guid } }
          hash
        end
      end

      let(:result) { described_class.new(service_plan, decorators: [FakeDecorator]).to_hash.deep_symbolize_keys }

      let(:service_plan) { VCAP::CloudController::ServicePlan.make }

      it 'uses the decorator' do
        expect(result[:included]).to match({ resource: { guid: service_plan.guid } })
      end
    end
  end
end
