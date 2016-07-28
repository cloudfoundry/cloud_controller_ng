require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe RouteMappingPresenter do
    subject { described_class.new }

    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }

    describe '#entity_hash' do
      let(:process) { VCAP::CloudController::AppFactory.make(diego: true) }
      let(:route) { route_mapping.route }
      let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(app: process, app_port: 9090) }

      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the route_mapping entity and associated urls' do
        expect(subject.entity_hash(controller, route_mapping, opts, depth, parents, orphans)).to eq(
          {
            'app_port'   => 9090,
            'app_guid'   => process.guid,
            'route_guid' => route.guid,
            'relationship_key' => 'relationship_value'
          }
        )

        expect(relations_presenter).to have_received(:to_hash).with(controller, route_mapping, opts, depth, parents, orphans)
      end
    end
  end
end
