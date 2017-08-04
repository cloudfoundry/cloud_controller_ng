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
    subject { described_class.new }

    describe '#entity_hash' do
      before do
        set_current_user_as_admin
      end

      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(create_instance_schema: create_instance_schema,
                                                update_instance_schema: update_instance_schema,
                                                create_binding_schema: create_binding_schema)
      end

      let(:create_instance_schema) { nil }
      let(:update_instance_schema) { nil }
      let(:create_binding_schema) { nil }

      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the service plan entity' do
        expect(subject.entity_hash(controller, service_plan, opts, depth, parents, orphans)).to eq(
          {
           'active' => true,
           'bindable' => true,
           'description' => service_plan.description,
           'extra' => nil,
           'free' => false,
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
    end
  end
end
