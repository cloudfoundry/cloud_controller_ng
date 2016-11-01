require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe OrganizationPresenter do
    let(:org_presenter) { described_class.new }
    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }
    let(:quota_definition) { VCAP::CloudController::QuotaDefinition.make }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:org) do
        VCAP::CloudController::Organization.make(
          name: 'george',
          billing_enabled: true,
          quota_definition_guid: quota_definition.guid,
          status: 'active',
        )
      end

      it 'returns the organization entity and associated urls' do
        expected_entity_hash = {
          'name'                  => 'george',
          'billing_enabled'       => true,
          'quota_definition_guid' => quota_definition.guid,
          'relationship_key'      => 'relationship_value',
          'status'                => 'active',
          'default_isolation_segment_guid' => nil,
        }

        actual_entity_hash = org_presenter.entity_hash(controller, org, opts, depth, parents, orphans)

        expect(actual_entity_hash).to be_a_response_like(expected_entity_hash)
        expect(relations_presenter).to have_received(:to_hash).with(controller, org, opts, depth, parents, orphans)
      end

      context 'with isolation segments assigned' do
        let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
        let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

        before do
          assigner.assign(isolation_segment_model, [org])
          org.update(default_isolation_segment_model: isolation_segment_model)
          org.reload
        end

        it 'displays the correct url' do
          actual_entity_hash = org_presenter.entity_hash(controller, org, opts, depth, parents, orphans)

          expect(actual_entity_hash['default_isolation_segment_guid']).to eq(isolation_segment_model.guid)
          expect(actual_entity_hash['isolation_segment_url']).to eq "/v2/organizations/#{org.guid}/isolation_segments"
          expect(relations_presenter).to have_received(:to_hash).with(controller, org, opts, depth, parents, orphans)
        end
      end
    end
  end
end
