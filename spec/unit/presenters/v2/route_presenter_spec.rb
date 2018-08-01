require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe RoutePresenter do
    subject { described_class.new }

    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:space) { VCAP::CloudController::Space.make }
      let(:domain) { VCAP::CloudController::SharedDomain.make }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(:routing, space: space) }
      let(:route) do
        VCAP::CloudController::Route.make(
          host:   'host',
          path:   '/some-path',
          domain: domain,
          space:  space,
        )
      end
      let!(:route_binding) { VCAP::CloudController::RouteBinding.make(route: route, service_instance: service_instance) }

      it 'returns the route entity and associated urls' do
        expect(subject.entity_hash(controller, route, opts, depth, parents, orphans)).to eq(
          {
            'host'                  => 'host',
            'path'                  => '/some-path',
            'domain_guid'           => domain.guid,
            'space_guid'            => space.guid,
            'service_instance_guid' => service_instance.guid,
            'port'                  => nil,
            'relationship_key' => 'relationship_value',
            'domain_url' => "/v2/shared_domains/#{domain.guid}"
          }
        )

        expect(relations_presenter).to have_received(:to_hash).with(controller, route, opts, depth, parents, orphans)
      end

      context 'when the domain is a private domain' do
        let(:domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: space.organization) }

        it 'uses the private_domains url' do
          expect(subject.entity_hash(controller, route, opts, depth, parents, orphans)).to include(
            {
              'domain_url' => "/v2/private_domains/#{domain.guid}"
            }
          )
        end
      end
    end
  end
end
