require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServicePlanPresenter do
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_url' => 'http://relationship.example.com' } }

    subject { ServicePlanPresenter.new }

    describe '#entity_hash' do
      before do
        set_current_user_as_admin
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(
          create_instance_schema:,
          update_instance_schema:,
          create_binding_schema:,
          maintenance_info:
        )
      end

      let(:maintenance_info) { { version: '2.0' } }

      let(:create_instance_schema) { nil }
      let(:update_instance_schema) { nil }
      let(:create_binding_schema) { nil }

      it 'returns the service plan entity' do
        expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to eq(
          {
            'active' => true,
            'bindable' => true,
            'plan_updateable' => nil,
            'description' => service_plan.description,
            'extra' => nil,
            'free' => false,
            'maintenance_info' => { 'version' => '2.0' },
            'maximum_polling_duration' => nil,
            'name' => service_plan.name,
            'public' => true,
            'relationship_url' => 'http://relationship.example.com',
            'schemas' => {
              'service_instance' => {
                'create' => { 'parameters' => {} },
                'update' => { 'parameters' => {} }
              },
              'service_binding' => {
                'create' => { 'parameters' => {} }
              }
            },
            'service_guid' => service_plan.service_guid,
            'unique_id' => service_plan.unique_id
          }
        )
      end

      context 'when the plan create_instance_schema, update_instance_schema and create_binding_schema are nil' do
        let(:create_instance_schema) { nil }
        let(:update_instance_schema) { nil }
        let(:create_binding_schema) { nil }

        it 'returns an empty schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
              'schemas' => {
                'service_instance' => {
                  'create' => { 'parameters' => {} },
                  'update' => { 'parameters' => {} }
                },
                'service_binding' => {
                  'create' => { 'parameters' => {} }
                }
              }
            }
          )
        end
      end

      context 'when the plan create_instance_schema is valid json' do
        schema = { '$schema' => 'example.com/schema' }
        let(:create_instance_schema) { schema.to_json }

        it 'returns the service plan entity with the schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
              'schemas' => {
                'service_instance' => {
                  'create' => { 'parameters' => schema },
                  'update' => { 'parameters' => {} }
                },
                'service_binding' => {
                  'create' => { 'parameters' => {} }
                }
              }
            }
          )
        end
      end

      context 'when the plan create_instance_schema is invalid json' do
        let(:create_instance_schema) { '{' }

        it 'returns an empty schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
              'schemas' => {
                'service_instance' => {
                  'create' => { 'parameters' => {} },
                  'update' => { 'parameters' => {} }
                },
                'service_binding' => {
                  'create' => { 'parameters' => {} }
                }
              }
            }
          )
        end
      end

      context 'when the plan update_instance_schema is valid json' do
        schema = { '$schema' => 'example.com/schema' }
        let(:update_instance_schema) { schema.to_json }

        it 'returns the service plan entity with the schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
              'schemas' => {
                'service_instance' => {
                  'create' => {
                    'parameters' => {}
                  },
                  'update' => {
                    'parameters' => schema
                  }
                },
                'service_binding' => {
                  'create' => {
                    'parameters' => {}
                  }
                }
              }
            }
          )
        end
      end

      context 'when the plan update_instance_schema is invalid json' do
        let(:update_instance_schema) { '{' }

        it 'returns an empty schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
              'schemas' => {
                'service_instance' => {
                  'create' => { 'parameters' => {} },
                  'update' => { 'parameters' => {} }
                },
                'service_binding' => {
                  'create' => { 'parameters' => {} }
                }
              }
            }
          )
        end
      end

      context 'when the plan create_binding_schema is valid json' do
        schema = { '$schema' => 'example.com/schema' }
        let(:create_binding_schema) { schema.to_json }

        it 'returns the service plan entity with the schema in the correct format' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to include(
            {
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
                    'parameters' => schema
                  }
                }
              }
            }
          )
        end
      end

      context 'when maintenance_info is available as string' do
        let(:maintenance_info) { '{"version": "2.0"}' }

        it 'includes `maintenance_info` in the entity' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)['maintenance_info']).to eq(
            {
              'version' => '2.0'
            }
          )
        end
      end

      context 'when maintenance_info is invalid JSON' do
        let(:maintenance_info) { 'invalid_json' }

        it 'returns empty JSON object for maintenance_info' do
          expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)['maintenance_info']).to eq({})
        end
      end
    end
  end
end
