require 'spec_helper'
require 'presenters/v3/space_ssh_feature_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpaceSshFeaturePresenter do
    let(:space) { VCAP::CloudController::Space.make }

    describe '#to_hash' do
      it 'presents the space feature as json' do
        result = SpaceSshFeaturePresenter.new(space).to_hash
        expect(result[:name]).to eq('ssh')
        expect(result[:description]).to eq('Enable SSHing into apps in the space.')
        expect(result[:enabled]).to eq(space.allow_ssh)
      end
    end
  end
end
