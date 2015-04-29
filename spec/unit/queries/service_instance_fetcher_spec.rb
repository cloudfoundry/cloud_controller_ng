require 'spec_helper'
require 'queries/service_instance_fetcher'

module VCAP::CloudController
  describe ServiceInstanceFetcher do
    describe '#fetch' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:service) { Service.make(:v2) }
      let(:plan) { ServicePlan.make(service: service) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: plan) }

      it 'should return the instance, the space, the plan, and the service' do
        fetcher = ServiceInstanceFetcher.new
        expect(fetcher.fetch(service_instance.guid)).to eq([service_instance, { space: space, plan: plan, service: service }])
      end

      context 'when the instance is user-provided' do
        let(:service_instance) { UserProvidedServiceInstance.make(space: space) }

        it 'should return just the instance and the space' do
          fetcher = ServiceInstanceFetcher.new
          expect(fetcher.fetch(service_instance.guid)).to eq([service_instance, { space: space, plan: nil, service: nil }])
        end
      end
    end
  end
end
