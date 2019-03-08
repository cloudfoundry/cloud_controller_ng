require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationInstanceUsageCalculator do
    describe '#get_instance_usage' do
      let!(:org) { FactoryBot.create(:organization) }
      let!(:space1) { FactoryBot.create(:space, organization: org) }
      let!(:space2) { FactoryBot.create(:space) }
      let!(:space3) { FactoryBot.create(:space, organization: org) }
      let!(:started_process1) { ProcessModelFactory.make(space: space1, instances: 3, state: 'STARTED') }
      let!(:started_process2) { ProcessModelFactory.make(space: space1, instances: 6, state: 'STARTED') }
      let!(:started_process3) { ProcessModelFactory.make(space: space3, instances: 7, state: 'STARTED') }
      let!(:stopped_process) { ProcessModelFactory.make(space: space1, instances: 2, state: 'STOPPED') }
      let!(:process2) { ProcessModelFactory.make(space: space2, instances: 5, state: 'STARTED') }

      it 'returns the number of instances for STARTED apps only in all spaces under the org' do
        result = OrganizationInstanceUsageCalculator.get_instance_usage(org)

        expect(result).to eq(started_process1.instances + started_process2.instances + started_process3.instances)
      end
    end
  end
end
