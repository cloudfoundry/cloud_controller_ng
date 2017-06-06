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
        VCAP::CloudController::ServicePlan.make
      end

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
           'schemas' => { 'service_instance' => { 'create' => { 'parameters' => {} } } },
           'service_guid' => service_plan.service_guid,
           'unique_id' => service_plan.unique_id
          }
        )
      end
    end
  end
end
