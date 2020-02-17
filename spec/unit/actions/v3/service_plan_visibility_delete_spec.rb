require 'spec_helper'
require 'actions/v3/service_plan_visibility_delete'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibilityDelete do
    describe '.delete' do
      let!(:visibility_1) { ServicePlanVisibility.make }
      let!(:visibility_2) { ServicePlanVisibility.make }

      it 'deletes the service plan visibility' do
        ServicePlanVisibilityDelete.delete(visibility_1)

        expect(visibility_1.exists?).to eq(false), 'Expected visibility 1 to not exist, but it does'
        expect(visibility_2.exists?).to eq(true), 'Expected visibility 2 to exist, but it does not'
      end
    end
  end
end
