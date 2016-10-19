require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceInstancePresenter do
    let(:controller) { 'controller' }
    let(:opts) { { export_attrs: ['name'] } }
    let(:depth) { 0 }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_url' => 'http://relationship.example.com' } }
    subject { described_class.new }

    describe '#entity_hash' do
      before do
        set_current_user_as_admin
      end

      let(:service_instance) do
        VCAP::CloudController::ServiceInstance.make(
          name: 'things',
        )
      end
      let(:service_plan) { VCAP::CloudController::ServicePlan.make }

      before do
        service_instance.service_plan_id = service_plan.id
        service_instance.save

        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the service instance entity' do
        expect(subject.entity_hash(controller, service_instance, opts, depth, parents, orphans)).to eq(
          {
            'name'              => service_instance.name,
            'service_plan_guid' => service_plan.guid,
            'service_guid'      => service_plan.service.guid,
            'relationship_url'  => 'http://relationship.example.com',
            'service_url'       => "/v2/services/#{service_plan.service.guid}"
          }
        )
      end
    end
  end
end
