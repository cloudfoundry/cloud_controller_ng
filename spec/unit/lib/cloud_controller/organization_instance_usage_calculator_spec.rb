require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationInstanceUsageCalculator do
    describe '#get_instance_usage' do
      let!(:org) { Organization.make }
      let!(:space1) { Space.make(organization: org) }
      let!(:space2) { Space.make }
      let!(:space3) { Space.make(organization: org) }
      let!(:started_process1) { AppFactory.make(space: space1, instances: 3, state: 'STARTED') }
      let!(:started_process2) { AppFactory.make(space: space1, instances: 6, state: 'STARTED') }
      let!(:started_process3) { AppFactory.make(space: space3, instances: 7, state: 'STARTED') }
      let!(:stopped_process) { AppFactory.make(space: space1, instances: 2, state: 'STOPPED') }
      let!(:process2) { AppFactory.make(space: space2, instances: 5, state: 'STARTED') }

      it 'returns the number of instances for STARTED apps only in all spaces under the org' do
        result = OrganizationInstanceUsageCalculator.get_instance_usage(org)

        expect(result).to eq(started_process1.instances + started_process2.instances + started_process3.instances)
      end
    end
  end
end
