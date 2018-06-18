require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe UserPresenter do
    subject { UserPresenter.new }

    let(:controller) { 'controller' }
    let(:opts) { {} }
    let(:depth) { 'depth' }
    let(:parents) { 'parents' }
    let(:orphans) { 'orphans' }
    let(:relations_presenter) { instance_double(RelationsPresenter, to_hash: relations_hash) }
    let(:relations_hash) { { 'relationship_key' => 'relationship_value' } }
    let(:organization) { VCAP::CloudController::Organization.make }
    let(:space) { VCAP::CloudController::Space.make(organization: organization) }

    describe '#entity_hash' do
      before do
        allow(RelationsPresenter).to receive(:new).and_return(relations_presenter)
      end

      let(:user) do
        user = make_developer_for_space(space)
        user.update(active: true, admin: false, default_space_guid: space.guid)
        user
      end

      it 'returns the user and associated urls' do
        expect(subject.entity_hash(controller, user, opts, depth, parents, orphans)).to eq(
          {
            'active' => true,
            'admin' => false,
            'default_space_guid' => space.guid,
            'relationship_key' => 'relationship_value',
          })
        expect(relations_presenter).to have_received(:to_hash).with(controller, user, opts, depth, parents, orphans)
      end
    end
  end
end
