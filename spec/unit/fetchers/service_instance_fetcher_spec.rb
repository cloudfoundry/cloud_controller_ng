require 'db_spec_helper'
require 'fetchers/service_instance_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceInstanceFetcher do
    describe '#fetch' do
      let(:org) { create(:organization) }
      let(:space) { create(:space, organization: org) }
      let(:service) { create(:service, :v2) }
      let(:plan) { create(:service_plan, service:) }
      let(:service_instance) { create(:managed_service_instance, space: space, service_plan: plan) }

      it 'returns the instance, the space, the plan, and the service' do
        fetcher = ServiceInstanceFetcher.new
        instance, related_objects = fetcher.fetch(service_instance.guid)

        expect(instance).to eq(service_instance)
        expect(related_objects).to eq({ space:, plan:, service: })
      end

      context 'when the instance is user-provided' do
        let(:service_instance) { create(:user_provided_service_instance, space:) }

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
