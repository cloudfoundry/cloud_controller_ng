require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/delete_route_binding_job'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteRouteBindingJob do
      let(:subject) do
        described_class.new(
          binding.guid,
          user_audit_info: user_info
        )
      end

      let(:space) { Space.make }
      let(:service_offering) { Service.make(requires: ['route_forwarding']) }
      let(:maximum_polling_duration) { nil }
      let(:service_plan) { ServicePlan.make(service: service_offering, maximum_polling_duration: maximum_polling_duration) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan, space: space) }
      let(:route) { Route.make(space: space) }
      let(:state) { 'in progress' }
      let(:binding) do
        RouteBinding.new.save_with_new_operation(
          {
            service_instance: service_instance,
            route: route,
          },
          {
            type: 'create',
            state: state,
          },
        )
      end
      let(:user_info) { instance_double(Object) }

      it_behaves_like 'delayed job', described_class

      describe '#operation' do
        it 'returns "unbind"' do
          expect(subject.operation).to eq(:unbind)
        end
      end

      describe '#operation_type' do
        it 'returns "delete"' do
          expect(subject.operation_type).to eq('delete')
        end
      end
    end
  end
end
