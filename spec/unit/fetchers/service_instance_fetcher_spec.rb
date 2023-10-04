require 'db_spec_helper'
require 'fetchers/service_instance_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceInstanceFetcher do
    describe '#fetch' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:service) { Service.make(:v2) }
      let(:plan) { ServicePlan.make(service:) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: plan) }

      it 'returns the instance, the space, the plan, and the service' do
        fetcher = ServiceInstanceFetcher.new
        instance, related_objects = fetcher.fetch(service_instance.guid)

        expect(instance).to eq(service_instance)
        expect(related_objects).to eq({ space:, plan:, service: })
      end

      context 'when the instance is user-provided' do
        let(:service_instance) { UserProvidedServiceInstance.make(space:) }

        it 'returns just the instance and the space' do
          fetcher = ServiceInstanceFetcher.new
          expect(fetcher.fetch(service_instance.guid)).to eq([service_instance, { space: space, plan: nil, service: nil }])
        end
      end

      context 'when the instance is not found' do
        it 'returns nil values for a bad guid' do
          fetcher = ServiceInstanceFetcher.new
          instance, related_objects = fetcher.fetch('bad-guid')
          expect(instance).to be_nil
          expect(related_objects).to be_nil
        end
      end
    end
  end
end
