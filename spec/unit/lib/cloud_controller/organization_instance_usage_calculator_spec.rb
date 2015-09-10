require 'spec_helper'

module VCAP::CloudController
  describe OrganizationInstanceUsageCalculator do
    describe '#get_instance_usage' do
      let!(:org) { Organization.make }
      let!(:space1) { Space.make(organization: org) }
      let!(:space2) { Space.make }
      let!(:space3) { Space.make(organization: org) }
      let!(:started_app1) { AppFactory.make(space: space1, instances: 3, state: 'STARTED') }
      let!(:started_app2) { AppFactory.make(space: space1, instances: 6, state: 'STARTED') }
      let!(:started_app3) { AppFactory.make(space: space3, instances: 7, state: 'STARTED') }
      let!(:stopped_app) { AppFactory.make(space: space1, instances: 2, state: 'STOPPED') }
      let!(:app2) { AppFactory.make(space: space2, instances: 5, state: 'STARTED') }

      it 'returns the number of instances for STARTED apps only in all spaces under the org' do
        result = OrganizationInstanceUsageCalculator.get_instance_usage(org)

        expect(result).to eq(started_app1.instances + started_app2.instances + started_app3.instances)
      end
    end
  end
end
