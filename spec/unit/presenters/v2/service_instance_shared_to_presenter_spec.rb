require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe ServiceInstanceSharedToPresenter do
    describe '#to_hash' do
      it 'returns the space and org name' do
        space = VCAP::CloudController::Space.make
        presenter = ServiceInstanceSharedToPresenter.new
        expect(presenter.to_hash(space)).to eq(
          {
            'space_name' => space.name,
            'organization_name' => space.organization.name,
          }
        )
      end
    end
  end
end
