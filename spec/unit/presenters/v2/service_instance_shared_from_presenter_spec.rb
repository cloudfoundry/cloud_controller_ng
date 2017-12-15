require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceInstanceSharedFromPresenter do
    describe '#to_hash' do
      it 'returns the space and org name' do
        space = VCAP::CloudController::Space.make
        presenter = ServiceInstanceSharedFromPresenter.new
        expect(presenter.to_hash(space)).to eq(
          {
            'space_guid' => space.guid,
            'space_name' => space.name,
            'organization_name' => space.organization.name,
          }
        )
      end
    end
  end
end
