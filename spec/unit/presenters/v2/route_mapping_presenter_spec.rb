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
      let(:app) { VCAP::CloudController::AppModel.make }
      let(:route) { VCAP::CloudController::Route.make(space: app.space) }
      let(:route_mapping) { VCAP::CloudController::RouteMappingModel.make(app: app, route: route, app_port: 9090) }

      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      it 'returns the route_mapping entity and associated urls' do
        expect(subject.entity_hash(controller, route_mapping, opts, depth, parents, orphans)).to eq(
          {
            'app_port'   => 9090,
            'app_guid'   => app.guid,
            'route_guid' => route.guid,
            'relationship_key' => 'relationship_value'
          }
        )

        expect(relations_presenter).to have_received(:to_hash).with(controller, route_mapping, opts, depth, parents, orphans)
      end

      context 'dea app' do
        before do
          VCAP::CloudController::App.make(app: app, type: 'web', diego: false)
        end

        it 'presents the app_port as nil' do
          entity = subject.entity_hash(controller, route_mapping, opts, depth, parents, orphans)
          expect(entity['app_port']).to be_nil
        end
      end
    end
  end
end
