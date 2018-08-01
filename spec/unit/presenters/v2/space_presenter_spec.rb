require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe SpacePresenter do
    let(:space_presenter) { described_class.new }
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:organization) { VCAP::CloudController::Organization.make }
      let(:space_quota_definition) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: organization) }

      context 'when a space is associated to an isolation segment' do
        let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
        let(:space) { VCAP::CloudController::Space.make(
          name: 'no_unicorns_no_rainbows',
          organization: organization,
          space_quota_definition: space_quota_definition,
          allow_ssh: true
          )
        }

        before do
          assigner.assign(isolation_segment_model, [organization])
          space.update(isolation_segment_model: isolation_segment_model)
        end

        it 'returns the space entity and associated urls' do
          expected_entity_hash = {
            'name'                        => space.name,
            'organization_guid'           => organization.guid,
            'space_quota_definition_guid' => space_quota_definition.guid,
            'isolation_segment_guid' => isolation_segment_model.guid,
            'allow_ssh'                   => space.allow_ssh,
            'relationship_key'            => 'relationship_value',
            'isolation_segment_url' => "/v3/isolation_segments/#{isolation_segment_model.guid}"
          }

          actual_entity_hash = space_presenter.entity_hash(controller, space, opts, depth, parents, orphans)

          expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
          expect(relations_presenter).to have_received(:to_hash).with(controller, space, opts, depth, parents, orphans)
        end
      end

      context 'when a space is not associated to an isolation segment' do
        let(:space) { VCAP::CloudController::Space.make(
          name: 'no_unicorns_no_rainbows',
          organization: organization,
          allow_ssh: true
          )
        }

        it 'returns the space and does not show isolation segment url' do
          expected_entity_hash = {
            'name'                        => space.name,
            'organization_guid'           => organization.guid,
            'space_quota_definition_guid' => nil,
            'isolation_segment_guid' => nil,
            'allow_ssh'                   => space.allow_ssh,
            'relationship_key'            => 'relationship_value'
          }

          actual_entity_hash = space_presenter.entity_hash(controller, space, opts, depth, parents, orphans)

          expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
          expect(actual_entity_hash).to_not include('isolation_segment_url')
          expect(relations_presenter).to have_received(:to_hash).with(controller, space, opts, depth, parents, orphans)
        end
      end
    end
  end
end
