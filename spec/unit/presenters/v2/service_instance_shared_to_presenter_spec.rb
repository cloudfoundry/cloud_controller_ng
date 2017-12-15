require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceInstanceSharedToPresenter do
    describe '#to_hash' do
      it 'returns the space name, org name, and bound app count' do
        space = VCAP::CloudController::Space.make
        presenter = ServiceInstanceSharedToPresenter.new
        expect(presenter.to_hash(space, 42)).to eq(
          {
            'space_guid' => space.guid,
            'space_name' => space.name,
            'organization_name' => space.organization.name,
            'bound_app_count' => 42
          }
        )
      end
    end
  end
end
