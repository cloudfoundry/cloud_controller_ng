require 'spec_helper'

RSpec.describe SpaceRoutes do
  subject { SpaceRoutes.new(space) }

  let(:space) { VCAP::CloudController::Space.make }

  describe '#count' do
    context 'when there are no routes' do
      its(:count) { is_expected.to eq 0 }
    end

    context 'when there are multiple routes' do
      before { 2.times { VCAP::CloudController::Route.make(space:) } }

      its(:count) { is_expected.to eq 2 }
    end

    context 'whyen there is a route belonging to different space' do
      before { VCAP::CloudController::Route.make(space: VCAP::CloudController::Space.make) }

      its(:count) { is_expected.to eq 0 }
    end
  end
end
