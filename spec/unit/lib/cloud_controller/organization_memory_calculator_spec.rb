require 'spec_helper'

module VCAP::CloudController
  describe OrganizationMemoryCalculator do
    describe '#get_memory_usage' do
      context 'with no apps' do
        it 'returns 0' do
          empty_org = Organization.make
          expect(OrganizationMemoryCalculator.get_memory_usage(empty_org)).to eq(0)
        end
      end

      context 'with apps' do
        let(:org) { Organization.make }
        let(:space_one) { Space.make(organization: org) }
        let(:space_two) { Space.make(organization: org) }
        let!(:app_one) { AppFactory.make(space: space_one, memory: 64, instances: 2, state: 'STARTED') }
        let!(:app_two) { AppFactory.make(space: space_two, memory: 64, instances: 2, state: 'STARTED') }

        it 'returns an aggregation of all app memory usage' do
          total_memory = (app_one.memory * app_one.instances) + (app_two.memory * app_two.instances)

          expect(OrganizationMemoryCalculator.get_memory_usage(org)).to eq(total_memory)
        end

        context 'when apps are stopped' do
          it 'does not include them in the total' do
            app_one.update(state: 'STOPPED')
            total_memory = (app_two.memory * app_two.instances)

            expect(OrganizationMemoryCalculator.get_memory_usage(org)).to eq(total_memory)
          end
        end
      end
    end
  end
end
